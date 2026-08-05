module Sales
  class CompleteSale
    def self.call(...)
      new(...).call
    end

    def initialize(
      organization:,
      branch:,
      cashier:,
      cart:,
      payment_plan:,
      sold_at: Time.current,
      due_on: nil,
      notes: nil
    )
      @organization = organization
      @branch = branch
      @cashier = cashier
      @cart = cart
      @payment_plan = payment_plan
      @sold_at = sold_at || Time.current

      @due_on =
        ActiveModel::Type::Date
          .new
          .cast(due_on)

      @notes = notes
    end

    def call
      validate_context!

      calculation = cart.calculation
      customer = cart.customer

      validate_customer!(
        customer,
        balance_due: payment_plan.balance_due
      )

      validate_payment_plan!(
        calculation: calculation
      )

      validate_credit_terms!(
        balance_due: payment_plan.balance_due
      )

      Sale.transaction do
        sale =
          create_sale!(
            calculation: calculation,
            customer: customer
          )

        create_sale_lines!(
          sale: sale,
          calculated_lines: calculation.lines
        )

        create_sale_payments!(sale)

        deduct_inventory!(
          sale: sale,
          calculated_lines: calculation.lines
        )

        sale
      end
    end

    private

    attr_reader :organization,
                :branch,
                :cashier,
                :cart,
                :payment_plan,
                :sold_at,
                :due_on,
                :notes

    def validate_context!
      unless organization&.persisted?
        raise Sales::CompletionError,
              "A saved organization is required"
      end

      validate_branch!
      validate_cashier!
      validate_cart_context!
      validate_payment_context!

      return unless cart.empty?

      raise Sales::CompletionError,
            "The cart is empty"
    end

    def validate_branch!
      unless branch&.persisted?
        raise Sales::CompletionError,
              "A saved branch is required"
      end

      unless branch.organization_id == organization.id
        raise Sales::CompletionError,
              "The branch belongs to another organization"
      end

      return if branch.active?

      raise Sales::CompletionError,
            "The selected branch is inactive"
    end

    def validate_cashier!
      unless cashier&.persisted?
        raise Sales::CompletionError,
              "A valid cashier is required"
      end

      membership =
        organization
          .memberships
          .active
          .find_by(user_id: cashier.id)

      unless membership&.pos_access?
        raise Sales::CompletionError,
              "The user cannot complete POS sales"
      end

      return if membership.branch_id.blank?
      return if membership.branch_id == branch.id

      raise Sales::CompletionError,
            "The cashier cannot sell from this branch"
    end

    def validate_cart_context!
      valid_organization =
        cart.organization.id == organization.id

      valid_branch =
        cart.branch.id == branch.id

      return if valid_organization && valid_branch

      raise Sales::CompletionError,
            "The cart does not belong to this POS branch"
    end

    def validate_payment_context!
      valid_organization =
        payment_plan.organization.id ==
          organization.id

      valid_branch =
        payment_plan.branch.id == branch.id

      return if valid_organization && valid_branch

      raise Sales::CompletionError,
            "The payment plan does not belong to this POS branch"
    end

    def validate_customer!(customer, balance_due:)
      if customer.blank?
        return if balance_due.to_d.zero?

        raise Sales::CompletionError,
              "Select a customer before recording a credit sale"
      end

      unless customer.organization_id == organization.id
        raise Sales::CompletionError,
              "The customer belongs to another organization"
      end

      return unless customer.respond_to?(:active?)
      return if customer.active?

      raise Sales::CompletionError,
            "The selected customer is inactive"
    end

    def validate_payment_plan!(calculation:)
      unless payment_plan.sale_total ==
             calculation.total
        raise Sales::CompletionError,
              "The payment plan no longer matches the cart total"
      end

      if payment_plan.applied_total >
         calculation.total
        raise Sales::CompletionError,
              "Payments exceed the sale total"
      end

      payment_plan.entries.each do |entry|
        validate_currency_amount!(
          entry.amount,
          label: "payment amount"
        )

        validate_currency_amount!(
          entry.amount_tendered,
          label: "tendered amount"
        )

        validate_currency_amount!(
          entry.change_given,
          label: "change amount"
        )
      end
    end

    def validate_currency_amount!(value, label:)
      return if value.to_d == value.to_d.round(2)

      raise Sales::CompletionError,
            "#{label.capitalize} cannot have more than " \
            "two decimal places"
    end

    def validate_credit_terms!(balance_due:)
      return if balance_due.to_d.zero?

      if due_on.blank?
        raise Sales::CompletionError,
              "Select a due date for the credit balance"
      end

      return if due_on >= sold_at.to_date

      raise Sales::CompletionError,
            "Credit due date cannot be before the sale date"
    end

    def create_sale!(calculation:, customer:)
      amount_paid =
        money(payment_plan.applied_total)

      balance_due =
        money(
          calculation.total - amount_paid
        )

      organization.sales.create!(
        branch: branch,
        customer: customer,
        cashier: cashier,
        sale_number:
          Sales::NextSaleNumber.call(
            branch: branch
          ),
        status: "completed",
        payment_status:
          payment_status_for(
            amount_paid: amount_paid,
            balance_due: balance_due
          ),
        sold_at: sold_at,
        due_on:
          balance_due.positive? ? due_on : nil,
        prices_include_tax: true,
        subtotal:
          money(calculation.subtotal),
        discount_total:
          money(calculation.discount_total),
        tax_total:
          money(calculation.tax_total),
        total:
          money(calculation.total),
        amount_paid: amount_paid,
        balance_due: balance_due,
        change_given:
          money(payment_plan.change_total),
        notes: notes
      )
    end

    def payment_status_for(
      amount_paid:,
      balance_due:
    )
      return "paid" if balance_due.zero?
      return "unpaid" if amount_paid.zero?

      "partially_paid"
    end

    def create_sale_lines!(
      sale:,
      calculated_lines:
    )
      calculated_lines.each do |attributes|
        sale.sale_lines.create!(
          attributes.merge(
            organization: organization
          )
        )
      end
    end

    def create_sale_payments!(sale)
      payment_plan.entries.each do |entry|
        sale.sale_payments.create!(
          organization: organization,
          payment_method:
            entry.payment_method,
          money_account:
            entry.money_account,
          recorded_by: cashier,
          amount:
            money(entry.amount),
          amount_tendered:
            money(entry.amount_tendered),
          change_given:
            money(entry.change_given),
          paid_at: sold_at,
          reference: entry.reference,
          notes: entry.notes
        )
      end
    end

   def deduct_inventory!(
      sale:,
      calculated_lines:
    )
      calculated_lines.each do |line|
        item = line[:item]

        next unless item.stockable?

        Inventory::DeductForSale.call(
          organization: organization,
          branch: branch,
          item: item,
          quantity: line[:quantity],
          recorded_by: cashier,
          occurred_at: sold_at,
          reference: sale.sale_number,
          notes:
            "Stock sold through #{sale.sale_number}",
          source: sale
        )
      end
    end

    def money(value)
      value.to_d.round(2)
    end
  end
end
