module Purchases
  class ReceivePurchase
    def self.call(...)
      new(...).call
    end

    def initialize(
      organization:,
      branch:,
      recorded_by:,
      cart:,
      received_at: Time.current
    )
      @organization = organization
      @branch = branch
      @recorded_by = recorded_by
      @cart = cart
      @received_at = received_at || Time.current
    end

    def call
      validate_context!

      supplier = cart.supplier
      calculation = cart.calculation

      Purchase.transaction do
        purchase =
          create_purchase!(
            supplier: supplier,
            calculation: calculation
          )

        purchase_lines =
        create_lines!(
            purchase: purchase,
            calculated_lines:
            calculation.lines
        )

        receive_stock!(
        purchase: purchase,
        calculated_lines:
            calculation.lines,
        purchase_lines: purchase_lines
        )

        purchase
      end
    end

    private

    attr_reader :organization,
                :branch,
                :recorded_by,
                :cart,
                :received_at

    def validate_context!
      unless organization&.persisted?
        raise Purchases::ReceivingError,
              "A saved organization is required"
      end

      validate_branch!
      validate_member!
      validate_cart!

      if cart.empty?
        raise Purchases::ReceivingError,
              "Add at least one item to the purchase"
      end

      if cart.supplier.blank?
        raise Purchases::ReceivingError,
              "Select a supplier"
      end

      if cart.purchased_on.blank?
        raise Purchases::ReceivingError,
              "Select the supplier invoice date"
      end
    end

    def validate_branch!
      unless branch&.persisted? &&
             branch.organization_id ==
               organization.id
        raise Purchases::ReceivingError,
              "The purchase branch is invalid"
      end

      return if branch.active?

      raise Purchases::ReceivingError,
            "The purchase branch is inactive"
    end

    def validate_member!
      membership =
        organization
          .memberships
          .active
          .find_by(
            user_id: recorded_by&.id
          )

      unless membership&.supplier_management?
        raise Purchases::ReceivingError,
              "The user cannot receive purchases"
      end

      return if membership.branch_id.blank?
      return if membership.branch_id ==
                branch.id

      raise Purchases::ReceivingError,
            "The user cannot receive stock for this branch"
    end

    def validate_cart!
      valid_organization =
        cart.organization.id ==
          organization.id

      valid_branch =
        cart.branch.id ==
          branch.id

      return if valid_organization &&
                valid_branch

      raise Purchases::ReceivingError,
            "The purchase cart belongs to another branch"
    end

    def create_purchase!(
      supplier:,
      calculation:
    )
      organization.purchases.create!(
        branch: branch,
        supplier: supplier,
        recorded_by: recorded_by,
        purchase_number:
          Purchases::NextPurchaseNumber.call(
            branch: branch
          ),
        supplier_invoice_number:
          cart.supplier_invoice_number,
        status: "received",
        payment_status: "unpaid",
        purchased_on: cart.purchased_on,
        received_at: received_at,
        prices_include_tax: true,
        subtotal:
          money(calculation.subtotal),
        discount_total:
          money(calculation.discount_total),
        tax_total:
          money(calculation.tax_total),
        total:
          money(calculation.total),
        amount_paid: 0,
        balance_due:
          money(calculation.total),
        notes: cart.notes
      )
    end

    def create_lines!(
        purchase:,
        calculated_lines:
        )
        calculated_lines.map do |line|
            purchase.purchase_lines.create!(
            organization: organization,
            item: line[:item],
            tax_rate: line[:tax_rate],
            line_number: line[:line_number],
            item_name: line[:item_name],
            sku: line[:sku],
            barcode: line[:barcode],
            item_type: line[:item_type],
            unit_name: line[:unit_name],
            unit_symbol: line[:unit_symbol],
            quantity: line[:quantity],
            unit_cost: line[:unit_cost],
            gross_amount:
                line[:gross_amount],
            discount_amount:
                line[:discount_amount],
            tax_percentage:
                line[:tax_percentage],
            tax_amount:
                line[:tax_amount],
            line_total:
                line[:line_total]
            )
        end
    end

    def receive_stock!(
        purchase:,
        calculated_lines:,
        purchase_lines:
        )
        calculated_lines
            .zip(purchase_lines)
            .each do |line, purchase_line|
            item = line[:item]

            batch =
                create_inventory_batch!(
                purchase_line: purchase_line,
                line: line
                )

            Inventory::PostMovement.call(
                organization: organization,
                branch: branch,
                item: item,
                recorded_by: recorded_by,
                movement_type: "purchase",
                quantity_change:
                line[:quantity],
                occurred_at: received_at,
                reference:
                cart.supplier_invoice_number.presence ||
                    purchase.purchase_number,
                notes:
                "Stock received from #{purchase.supplier.name}",
                source: purchase,
                inventory_batch: batch
            )

            update_latest_purchase_cost!(
                item: item,
                unit_cost: line[:unit_cost]
            )
         end
     end

    def update_latest_purchase_cost!(
      item:,
      unit_cost:
    )
      item.with_lock do
        item.update!(
          purchase_cost:
            money(unit_cost)
        )
      end
    end

    def create_inventory_batch!(
        purchase_line:,
        line:
        )
        item = line[:item]

        return unless item.tracks_expiry?

        cart_line =
            cart.lines.find do |candidate|
            candidate.item.id == item.id
            end

        validate_expiry_information!(
            item: item,
            cart_line: cart_line
        )

        organization.inventory_batches.create!(
            branch: branch,
            item: item,
            purchase_line: purchase_line,
            batch_number:
            cart_line.batch_number,
            manufactured_on:
            cart_line.manufactured_on,
            expires_on:
            cart_line.expires_on,
            quantity_received:
            line[:quantity],
            quantity_remaining:
            line[:quantity],
            unit_cost:
            money(line[:unit_cost]),
            received_at: received_at,
            status: "active"
        )
    end

        def validate_expiry_information!(
        item:,
        cart_line:
        )
        if cart_line.blank? ||
            cart_line.expires_on.blank?
            raise Purchases::ReceivingError,
                "Enter an expiry date for #{item.name}"
        end

        if cart_line.expires_on <
            received_at.to_date
            raise Purchases::ReceivingError,
                "#{item.name} expiry date cannot be in the past"
        end

        return if cart_line.manufactured_on.blank?
        return if cart_line.manufactured_on <=
                    cart_line.expires_on

        raise Purchases::ReceivingError,
                "#{item.name} manufacture date cannot be after its expiry date"
        end

    def money(value)
      value.to_d.round(2)
    end
  end
end
