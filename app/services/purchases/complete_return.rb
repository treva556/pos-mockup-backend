module Purchases
  class CompleteReturn
    def self.call(...)
      new(...).call
    end

    def initialize(
      organization:,
      purchase:,
      recorded_by:,
      lines:,
      reason_code:,
      supplier_document_number: nil,
      reason_details: nil,
      notes: nil,
      returned_at: Time.current
    )
      @organization = organization
      @purchase = purchase
      @recorded_by = recorded_by
      @lines = Array(lines)

      @reason_code =
        reason_code.to_s

      @supplier_document_number =
        supplier_document_number

      @reason_details =
        reason_details

      @notes =
        notes

      @returned_at =
        ActiveModel::Type::DateTime
          .new
          .cast(returned_at)
    end

    def call
      validate_context!

      PurchaseReturn.transaction do
        purchase.lock!
        purchase.reload

        validate_locked_purchase!

        prepared_lines =
          prepare_lines!

        purchase_return =
          create_return!

        create_return_lines!(
          purchase_return: purchase_return,
          prepared_lines: prepared_lines
        )

        complete_return!(
          purchase_return
        )

        deduct_inventory!(
          purchase_return
        )

        purchase_return
      end
    rescue ActiveRecord::RecordInvalid => error
      message =
        error
          .record
          .errors
          .full_messages
          .to_sentence

      raise Purchases::ReturnError,
            message.presence || error.message
    rescue Inventory::InsufficientStockError => error
      raise Purchases::ReturnError,
            error.message
    end

    private

    attr_reader :organization,
                :purchase,
                :recorded_by,
                :lines,
                :reason_code,
                :supplier_document_number,
                :reason_details,
                :notes,
                :returned_at

    def validate_context!
      unless organization&.persisted?
        raise Purchases::ReturnError,
              "A saved organization is required"
      end

      unless purchase&.organization_id ==
             organization.id
        raise Purchases::ReturnError,
              "The purchase belongs to another organization"
      end

      validate_member!

      unless PurchaseReturn
               .reason_codes
               .key?(reason_code)
        raise Purchases::ReturnError,
              "Select a valid purchase return reason"
      end

      if returned_at.blank?
        raise Purchases::ReturnError,
              "Select the return date and time"
      end

      return if lines.any?

      raise Purchases::ReturnError,
            "Select at least one item to return"
    end

    def validate_member!
      membership =
        organization
          .memberships
          .active
          .find_by(
            user_id: recorded_by&.id
          )

      unless membership&.purchase_return_management?
        raise Purchases::ReturnError,
              "The user cannot process purchase returns"
      end

      return if membership.branch_id.blank?

      return if membership.branch_id ==
                purchase.branch_id

      raise Purchases::ReturnError,
            "The user cannot return purchases from this branch"
    end

    def validate_locked_purchase!
      unless purchase.received?
        raise Purchases::ReturnError,
              "Only received purchases can be returned"
      end

      return if purchase.branch.active?

      raise Purchases::ReturnError,
            "The purchase branch is inactive"
    end

    def prepare_lines!
      seen_purchase_lines = {}

      lines.each_with_index.map do |raw_line, index|
        attributes =
          raw_line
            .to_h
            .symbolize_keys

        source_line =
          find_source_line!(
            attributes[:purchase_line_id]
          )

        if seen_purchase_lines[source_line.id]
          raise Purchases::ReturnError,
                "#{source_line.item_name} was selected more than once"
        end

        seen_purchase_lines[source_line.id] = true

        quantity =
          decimal_value(
            attributes[:quantity],
            label:
              "#{source_line.item_name} return quantity"
          )

        validate_quantity!(
          source_line: source_line,
          quantity: quantity
        )

        batch =
          inventory_batch_for!(
            source_line: source_line,
            quantity: quantity
          )

        allocation =
          allocation_for(
            source_line: source_line,
            quantity: quantity
          )

        {
          line_number: index + 1,
          source_line: source_line,
          quantity: quantity,
          inventory_batch: batch,
          reason_code:
            attributes[:reason_code]
              .presence ||
              reason_code,
          notes:
            attributes[:notes],
          allocation: allocation
        }
      end
    end

    def find_source_line!(purchase_line_id)
      source_line =
        purchase
          .purchase_lines
          .includes(
            item: :unit_of_measure
          )
          .find_by(
            id: purchase_line_id
          )

      return source_line if source_line

      raise Purchases::ReturnError,
            "A selected item does not belong to this purchase"
    end

    def validate_quantity!(
      source_line:,
      quantity:
    )
      unless quantity.positive?
        raise Purchases::ReturnError,
              "#{source_line.item_name} return quantity " \
              "must be greater than zero"
      end

      unit =
        source_line
          .item
          .unit_of_measure

      if !unit.decimal_allowed? &&
         (quantity % 1).nonzero?
        raise Purchases::ReturnError,
              "#{source_line.item_name} must be returned " \
              "in whole units"
      end

      available =
        source_line.returnable_quantity

      return if quantity <= available

      raise Purchases::ReturnError,
            "#{source_line.item_name} only has " \
            "#{available.to_s('F')} returnable units"
    end

    def inventory_batch_for!(
      source_line:,
      quantity:
    )
      item =
        source_line.item

      return nil unless item.tracks_expiry?

      batch =
        source_line.inventory_batch

      unless batch
        raise Purchases::ReturnError,
              "#{source_line.item_name} does not have " \
              "its original inventory batch"
      end

      batch.lock!
      batch.reload

      return batch if batch
        .quantity_remaining
        .to_d >= quantity

      raise Purchases::ReturnError,
            "#{source_line.item_name} only has " \
            "#{batch.quantity_remaining.to_d.to_s('F')} " \
            "units remaining in its original batch"
    end

    def allocation_for(
      source_line:,
      quantity:
    )
      final_quantity =
        quantity ==
          source_line.returnable_quantity

      if final_quantity
        return {
          gross_amount:
            remaining_money(
              source_line,
              :gross_amount
            ),
          discount_amount:
            remaining_money(
              source_line,
              :discount_amount
            ),
          tax_amount:
            remaining_money(
              source_line,
              :tax_amount
            ),
          line_total:
            remaining_money(
              source_line,
              :line_total
            )
        }
      end

      ratio =
        quantity /
          source_line.quantity.to_d

      {
        gross_amount:
          money(
            source_line.gross_amount.to_d *
              ratio
          ),
        discount_amount:
          money(
            source_line.discount_amount.to_d *
              ratio
          ),
        tax_amount:
          money(
            source_line.tax_amount.to_d *
              ratio
          ),
        line_total:
          money(
            source_line.line_total.to_d *
              ratio
          )
      }
    end

    def remaining_money(
      source_line,
      column
    )
      already_returned =
        source_line
          .purchase_return_lines
          .joins(:purchase_return)
          .where(
            purchase_returns: {
              status: "completed"
            }
          )
          .sum(column)
          .to_d

      money(
        source_line
          .public_send(column)
          .to_d -
          already_returned
      )
    end

    def create_return!
      organization
        .purchase_returns
        .create!(
          branch: purchase.branch,
          purchase: purchase,
          recorded_by: recorded_by,
          return_number:
            Returns::NextPurchaseReturnNumber.call(
              branch: purchase.branch
            ),
          status: "draft",
          reason_code: reason_code,
          supplier_document_number:
            supplier_document_number,
          reason_details:
            reason_details,
          notes: notes,
          returned_at: nil,
          subtotal: 0,
          discount_total: 0,
          tax_total: 0,
          total: 0
        )
    end

    def create_return_lines!(
      purchase_return:,
      prepared_lines:
    )
      prepared_lines.each do |entry|
        source =
          entry[:source_line]

        allocation =
          entry[:allocation]

        purchase_return
          .purchase_return_lines
          .create!(
            organization: organization,
            purchase_line: source,
            item: source.item,
            inventory_batch:
              entry[:inventory_batch],
            line_number:
              entry[:line_number],
            item_name:
              source.item_name,
            sku:
              source.sku,
            barcode:
              source.barcode,
            item_type:
              source.item_type,
            unit_name:
              source.unit_name,
            unit_symbol:
              source.unit_symbol,
            quantity:
              entry[:quantity],
            unit_cost:
              source.unit_cost,
            gross_amount:
              allocation[:gross_amount],
            discount_amount:
              allocation[:discount_amount],
            tax_percentage:
              source.tax_percentage,
            tax_amount:
              allocation[:tax_amount],
            line_total:
              allocation[:line_total],
            reason_code:
              entry[:reason_code],
            notes:
              entry[:notes]
          )
      end
    end

    def complete_return!(
      purchase_return
    )
      return_lines =
        purchase_return
          .purchase_return_lines

      purchase_return.update!(
        subtotal:
          money(
            return_lines.sum(
              :gross_amount
            )
          ),
        discount_total:
          money(
            return_lines.sum(
              :discount_amount
            )
          ),
        tax_total:
          money(
            return_lines.sum(
              :tax_amount
            )
          ),
        total:
          money(
            return_lines.sum(
              :line_total
            )
          ),
        returned_at:
          returned_at,
        status:
          "completed"
      )
    end

    def deduct_inventory!(
      purchase_return
    )
      purchase_return
        .purchase_return_lines
        .includes(
          :item,
          :inventory_batch
        )
        .ordered
        .each do |line|
          item =
            line.item

          next unless item.stockable?

          if item.tracks_expiry?
            deduct_batch_stock!(
              purchase_return:
                purchase_return,
              line: line
            )
          else
            post_return_movement!(
              purchase_return:
                purchase_return,
              line: line,
              batch: nil
            )
          end
        end
    end

    def deduct_batch_stock!(
      purchase_return:,
      line:
    )
      batch =
        line.inventory_batch

      unless batch
        raise Purchases::ReturnError,
              "#{line.item_name} has no return batch"
      end

      batch.lock!
      batch.reload

      remaining =
        batch.quantity_remaining.to_d

      quantity =
        line.quantity.to_d

      if quantity > remaining
        raise Purchases::ReturnError,
              "#{line.item_name} only has " \
              "#{remaining.to_s('F')} units " \
              "remaining in its original batch"
      end

      batch.update!(
        quantity_remaining:
          remaining - quantity
      )

      post_return_movement!(
        purchase_return:
          purchase_return,
        line: line,
        batch: batch
      )
    end

    def post_return_movement!(
      purchase_return:,
      line:,
      batch:
    )
      Inventory::PostMovement.call(
        organization: organization,
        branch: purchase.branch,
        item: line.item,
        recorded_by: recorded_by,
        movement_type: "purchase_return",
        quantity_change:
          -line.quantity.to_d,
        occurred_at:
          returned_at,
        reference:
          purchase_return.return_number,
        notes:
          "Stock returned to " \
          "#{purchase.supplier.name}",
        source:
          purchase_return,
        inventory_batch:
          batch
      )
    end

    def decimal_value(value, label:)
      BigDecimal(value.to_s)
    rescue ArgumentError, TypeError
      raise Purchases::ReturnError,
            "Invalid #{label}"
    end

    def money(value)
      value.to_d.round(2)
    end
  end
end
