module Sales
  class CompleteReturn
    MONEY_FIELDS = %i[
      gross_amount
      discount_amount
      tax_amount
      line_total
    ].freeze

    STOCK_DISPOSITIONS = %w[
      restock
      quarantine
      damaged
      expired
      not_applicable
    ].freeze

    def self.call(...)
      new(...).call
    end

    def initialize(
      organization:,
      sale:,
      recorded_by:,
      lines:,
      reason_code: "other",
      reason_details: nil,
      notes: nil,
      returned_at: Time.current
    )
      @organization = organization
      @sale = sale
      @recorded_by = recorded_by
      @lines = lines
      @reason_code = reason_code.to_s
      @reason_details = reason_details
      @notes = notes

      @returned_at =
        ActiveModel::Type::DateTime
          .new
          .cast(returned_at)
    end

    def call
      validate_context!

      SaleReturn.transaction do
        sale.with_lock do
          sale.reload

          validate_sale!

          prepared_lines =
            prepare_lines!

          validate_combined_quantities!(
            prepared_lines
          )

          assign_money_amounts!(
            prepared_lines
          )

          sale_return =
            create_sale_return!

          create_return_lines!(
            sale_return: sale_return,
            prepared_lines: prepared_lines
          )

          complete_sale_return!(
            sale_return
          )

          restore_inventory!(
            sale_return
          )

          sale_return.reload
        end
      end
    rescue ActiveRecord::RecordInvalid => error
      raise Sales::ReturnError,
            error.record.errors
              .full_messages
              .to_sentence
    end

    private

    attr_reader :organization,
                :sale,
                :recorded_by,
                :lines,
                :reason_code,
                :reason_details,
                :notes,
                :returned_at

    def validate_context!
      unless organization&.persisted?
        raise Sales::ReturnError,
              "A saved organization is required"
      end

      unless sale&.persisted?
        raise Sales::ReturnError,
              "A saved sale is required"
      end

      unless sale.organization_id ==
             organization.id
        raise Sales::ReturnError,
              "The sale belongs to another organization"
      end

      unless returned_at.present?
        raise Sales::ReturnError,
              "Select the return date and time"
      end

      unless lines.is_a?(Array) &&
             lines.any?
        raise Sales::ReturnError,
              "Select at least one item to return"
      end

      validate_member!
    end

    def validate_member!
      membership =
        organization
          .memberships
          .active
          .find_by(
            user_id: recorded_by&.id
          )

      unless membership&.sales_return_management?
        raise Sales::ReturnError,
              "The user cannot process sales returns"
      end

      return if membership.branch_id.blank?

      return if membership.branch_id ==
                sale.branch_id

      raise Sales::ReturnError,
            "The user cannot process returns for this branch"
    end

    def validate_sale!
      unless sale.completed?
        raise Sales::ReturnError,
              "Only completed sales can be returned"
      end

      unless sale.branch.active?
        raise Sales::ReturnError,
              "The sale branch is inactive"
      end
    end

    def prepare_lines!
      lines.each_with_index.map do |raw_line, index|
        prepare_line!(
          raw_line,
          line_number: index + 1
        )
      end
    end

    def prepare_line!(
      raw_line,
      line_number:
    )
      attributes =
        raw_line
          .to_h
          .symbolize_keys

      source_line =
        sale.sale_lines.find_by(
          id: attributes[:sale_line_id]
        )

      unless source_line
        raise Sales::ReturnError,
              "A selected item does not belong to this sale"
      end

      quantity =
        decimal_value(
          attributes[:quantity],
          label: "return quantity"
        )

      disposition =
        attributes[
          :stock_disposition
        ].to_s

      disposition =
        default_disposition_for(
          source_line
        ) if disposition.blank?

      unless STOCK_DISPOSITIONS
        .include?(disposition)
        raise Sales::ReturnError,
              "Invalid stock disposition for " \
              "#{source_line.item_name}"
      end

      batch =
        find_inventory_batch!(
          attributes[:inventory_batch_id]
        )

      validate_line!(
        source_line: source_line,
        quantity: quantity,
        disposition: disposition,
        batch: batch
      )

      {
        line_number: line_number,
        sale_line: source_line,
        item: source_line.item,
        inventory_batch: batch,
        quantity: quantity,
        stock_disposition: disposition,
        reason_code:
          attributes[:reason_code]
            .to_s
            .strip
            .presence,
        notes:
          attributes[:notes]
            .to_s
            .strip
            .presence
      }
    end

    def default_disposition_for(source_line)
      if source_line.item.stockable?
        "restock"
      else
        "not_applicable"
      end
    end

    def find_inventory_batch!(batch_id)
      return nil if batch_id.blank?

      batch =
        organization
          .inventory_batches
          .find_by(id: batch_id)

      return batch if batch

      raise Sales::ReturnError,
            "The selected inventory batch is invalid"
    end

    def validate_line!(
      source_line:,
      quantity:,
      disposition:,
      batch:
    )
      unless quantity.positive?
        raise Sales::ReturnError,
              "#{source_line.item_name} return quantity " \
              "must be greater than zero"
      end

      validate_quantity_precision!(
        source_line,
        quantity
      )

      item =
        source_line.item

      if item.stockable?
        validate_stockable_line!(
          source_line: source_line,
          quantity: quantity,
          disposition: disposition,
          batch: batch
        )
      else
        validate_service_line!(
          source_line: source_line,
          disposition: disposition,
          batch: batch
        )
      end
    end

    def validate_quantity_precision!(
      source_line,
      quantity
    )
      unit =
        source_line
          .item
          .unit_of_measure

      return if unit.blank?
      return if unit.decimal_allowed?
      return if (quantity % 1).zero?

      raise Sales::ReturnError,
            "#{source_line.item_name} must be " \
            "returned in whole units"
    end

    def validate_service_line!(
      source_line:,
      disposition:,
      batch:
    )
      unless disposition ==
             "not_applicable"
        raise Sales::ReturnError,
              "#{source_line.item_name} is not a stock item"
      end

      return if batch.blank?

      raise Sales::ReturnError,
            "Services cannot use inventory batches"
    end

    def validate_stockable_line!(
      source_line:,
      quantity:,
      disposition:,
      batch:
    )
      if disposition ==
         "not_applicable"
        raise Sales::ReturnError,
              "#{source_line.item_name} requires a stock disposition"
      end

      item =
        source_line.item

      if item.tracks_expiry?
        validate_expiry_line!(
          source_line: source_line,
          quantity: quantity,
          disposition: disposition,
          batch: batch
        )
      elsif batch.present?
        raise Sales::ReturnError,
              "#{source_line.item_name} does not use inventory batches"
      end

      if disposition == "expired" &&
         !item.tracks_expiry?
        raise Sales::ReturnError,
              "#{source_line.item_name} is not expiry tracked"
      end
    end

    def validate_expiry_line!(
      source_line:,
      quantity:,
      disposition:,
      batch:
    )
      unless batch
        raise Sales::ReturnError,
              "Select the original batch for " \
              "#{source_line.item_name}"
      end

      valid_context =
        batch.branch_id ==
          sale.branch_id &&
        batch.item_id ==
          source_line.item_id

      unless valid_context
        raise Sales::ReturnError,
              "The selected batch does not match " \
              "#{source_line.item_name}"
      end

      available =
        batch_returnable_quantity(
          source_line,
          batch
        )

      unless quantity <= available
        raise Sales::ReturnError,
              "#{source_line.item_name} only has " \
              "#{available.to_s('F')} returnable units " \
              "from this batch"
      end

      return unless disposition ==
                    "restock"

      if batch.expired?(
        returned_at.to_date
      )
        raise Sales::ReturnError,
              "Expired stock cannot be returned to sellable inventory"
      end

      return unless batch.quarantined?

      raise Sales::ReturnError,
            "A quarantined batch cannot be returned " \
            "to sellable inventory"
    end

    def batch_returnable_quantity(
      source_line,
      batch
    )
      sold_quantity =
        sale
          .stock_movements
          .where(
            movement_type: "sale",
            item_id:
              source_line.item_id,
            inventory_batch_id:
              batch.id
          )
          .sum(:quantity_change)
          .to_d
          .abs

      returned_quantity =
        source_line
          .sale_return_lines
          .joins(:sale_return)
          .where(
            inventory_batch_id:
              batch.id,
            sale_returns: {
              status: "completed"
            }
          )
          .sum(:quantity)
          .to_d

      [
        sold_quantity -
          returned_quantity,
        0.to_d
      ].max
    end

    def validate_combined_quantities!(
      prepared_lines
    )
      prepared_lines
        .group_by do |line|
          line[:sale_line].id
        end
        .each_value do |group|
          validate_source_quantity_group!(
            group
          )
        end

      prepared_lines
        .select do |line|
          line[:inventory_batch].present?
        end
        .group_by do |line|
          [
            line[:sale_line].id,
            line[:inventory_batch].id
          ]
        end
        .each_value do |group|
          validate_batch_quantity_group!(
            group
          )
        end
    end

    def validate_source_quantity_group!(
      group
    )
      source_line =
        group.first[:sale_line]

      requested =
        group.sum do |line|
          line[:quantity]
        end

      available =
        source_line
          .returnable_quantity

      return if requested <= available

      raise Sales::ReturnError,
            "#{source_line.item_name} only has " \
            "#{available.to_s('F')} remaining " \
            "returnable units"
    end

    def validate_batch_quantity_group!(
      group
    )
      source_line =
        group.first[:sale_line]

      batch =
        group.first[:inventory_batch]

      requested =
        group.sum do |line|
          line[:quantity]
        end

      available =
        batch_returnable_quantity(
          source_line,
          batch
        )

      return if requested <= available

      raise Sales::ReturnError,
            "#{source_line.item_name} only has " \
            "#{available.to_s('F')} returnable units " \
            "from this batch"
    end

    def assign_money_amounts!(
      prepared_lines
    )
      prepared_lines
        .group_by do |line|
          line[:sale_line].id
        end
        .each_value do |group|
          assign_group_money_amounts!(
            group
          )
        end
    end

    def assign_group_money_amounts!(
      group
    )
      source_line =
        group.first[:sale_line]

      available_quantity =
        source_line
          .returnable_quantity

      requested_quantity =
        group.sum do |line|
          line[:quantity]
        end

      remaining_amounts =
        remaining_source_amounts(
          source_line
        )

      assigned =
        MONEY_FIELDS.index_with do
          0.to_d
        end

      group.each_with_index do |line, index|
        final_line =
          index ==
            group.length - 1

        exhausting_remaining =
          requested_quantity ==
            available_quantity

        MONEY_FIELDS.each do |field|
          amount =
            if final_line &&
               exhausting_remaining
              remaining_amounts[field] -
                assigned[field]
            else
              proportional_amount(
                source_line.public_send(field),
                line[:quantity],
                source_line.quantity
              )
            end

          line[field] =
            money(amount)

          assigned[field] +=
            line[field]
        end
      end
    end

    def remaining_source_amounts(
      source_line
    )
      completed_lines =
        source_line
          .sale_return_lines
          .joins(:sale_return)
          .where(
            sale_returns: {
              status: "completed"
            }
          )

      MONEY_FIELDS.index_with do |field|
        original =
          source_line
            .public_send(field)
            .to_d

        already_returned =
          completed_lines
            .sum(field)
            .to_d

        original -
          already_returned
      end
    end

    def proportional_amount(
      original_amount,
      return_quantity,
      original_quantity
    )
      return 0.to_d if
        original_quantity.to_d.zero?

      original_amount.to_d *
        return_quantity.to_d /
        original_quantity.to_d
    end

    def create_sale_return!
      organization.sale_returns.create!(
        branch: sale.branch,
        sale: sale,
        recorded_by: recorded_by,
        return_number:
          Returns::NextSaleReturnNumber.call(
            branch: sale.branch
          ),
        status: "draft",
        reason_code: reason_code,
        reason_details: reason_details,
        notes: notes,
        subtotal: 0,
        discount_total: 0,
        tax_total: 0,
        total: 0
      )
    end

    def create_return_lines!(
      sale_return:,
      prepared_lines:
    )
      prepared_lines.each do |line|
        source =
          line[:sale_line]

        sale_return
          .sale_return_lines
          .create!(
            organization: organization,
            sale_line: source,
            item: source.item,
            inventory_batch:
              line[:inventory_batch],
            line_number:
              line[:line_number],
            item_name:
              source.item_name,
            sku: source.sku,
            barcode: source.barcode,
            item_type:
              source.item_type,
            unit_name:
              source.unit_name,
            unit_symbol:
              source.unit_symbol,
            quantity:
              line[:quantity],
            unit_price:
              source.unit_price,
            unit_cost:
              source.unit_cost,
            gross_amount:
              line[:gross_amount],
            discount_amount:
              line[:discount_amount],
            tax_rate_percentage:
              source.tax_rate_percentage,
            tax_amount:
              line[:tax_amount],
            line_total:
              line[:line_total],
            stock_disposition:
              line[:stock_disposition],
            reason_code:
              line[:reason_code],
            notes:
              line[:notes]
          )
      end
    end

    def complete_sale_return!(
      sale_return
    )
      lines =
        sale_return
          .sale_return_lines

      sale_return.update!(
        subtotal:
          money(
            lines.sum(:gross_amount)
          ),
        discount_total:
          money(
            lines.sum(:discount_amount)
          ),
        tax_total:
          money(
            lines.sum(:tax_amount)
          ),
        total:
          money(
            lines.sum(:line_total)
          ),
        returned_at:
          returned_at,
        status: "completed"
      )
    end

    def restore_inventory!(
      sale_return
    )
      sale_return
        .sale_return_lines
        .includes(
          :item,
          :inventory_batch
        )
        .ordered
        .each do |line|
        next unless line.stock_restock?
        next unless line.item.stockable?

        if line.inventory_batch
          restore_batch_inventory!(
            sale_return: sale_return,
            line: line
          )
        else
          post_return_movement!(
            sale_return: sale_return,
            line: line
          )
        end
      end
    end

    def restore_batch_inventory!(
      sale_return:,
      line:
    )
      batch =
        line.inventory_batch

      batch.with_lock do
        batch.reload

        if batch.quarantined?
          raise Sales::ReturnError,
                "The return batch is quarantined"
        end

        if batch.expired?(
          returned_at.to_date
        )
          raise Sales::ReturnError,
                "Expired stock cannot be restocked"
        end

        new_quantity =
          batch.quantity_remaining.to_d +
          line.quantity.to_d

        if new_quantity >
           batch.quantity_received.to_d
          raise Sales::ReturnError,
                "The return would exceed the " \
                "original batch quantity"
        end

        batch.update!(
          quantity_remaining:
            new_quantity,
          status: "active"
        )

        post_return_movement!(
          sale_return: sale_return,
          line: line
        )
      end
    end

    def post_return_movement!(
      sale_return:,
      line:
    )
      Inventory::PostMovement.call(
        organization: organization,
        branch: sale.branch,
        item: line.item,
        recorded_by: recorded_by,
        movement_type: "sale_return",
        quantity_change:
          line.quantity,
        occurred_at:
          returned_at,
        reference:
          sale_return.return_number,
        notes:
          "Customer return for " \
          "#{sale.sale_number}",
        source: sale_return,
        inventory_batch:
          line.inventory_batch
      )
    end

    def decimal_value(
      value,
      label:
    )
      BigDecimal(value.to_s)
    rescue ArgumentError,
           TypeError
      raise Sales::ReturnError,
            "Invalid #{label}"
    end

    def money(value)
      value.to_d.round(2)
    end
  end
end
