module Sales
  class RecordCustomerPayment
    def self.call(...)
      new(...).call
    end

    def initialize(
      organization:,
      sale:,
      recorded_by:,
      payment_method:,
      money_account:,
      amount:,
      amount_tendered: nil,
      paid_at: Time.current,
      reference: nil,
      notes: nil
    )
      @organization = organization
      @sale = sale
      @recorded_by = recorded_by
      @payment_method = payment_method
      @money_account = money_account

      @amount =
        decimal_value(
          amount,
          label: "payment amount"
        )

      @amount_tendered =
        if amount_tendered.present?
          decimal_value(
            amount_tendered,
            label: "tendered amount"
          )
        else
          @amount
        end

      @paid_at =
        ActiveModel::Type::DateTime
          .new
          .cast(paid_at)

      @reference = reference
      @notes = notes
    end

    def call
      validate_context!

      Sale.transaction do
        sale.with_lock do
          sale.reload

          validate_outstanding_balance!

          payment =
            create_payment!

          update_sale_totals!

          payment
        end
      end
    end

    private

    attr_reader :organization,
                :sale,
                :recorded_by,
                :payment_method,
                :money_account,
                :amount,
                :amount_tendered,
                :paid_at,
                :reference,
                :notes

    def validate_context!
      unless sale.organization_id ==
             organization.id
        raise Sales::InvalidCustomerPaymentError,
              "The sale belongs to another organization"
      end

      unless sale.completed?
        raise Sales::InvalidCustomerPaymentError,
              "Only completed sales can receive payments"
      end

      if sale.customer.blank?
        raise Sales::InvalidCustomerPaymentError,
              "The sale has no customer account"
      end

      validate_member!
      validate_payment_method!
      validate_money_account!
      validate_amounts!
    end

    def validate_member!
      membership =
        organization
          .memberships
          .active
          .find_by(
            user_id: recorded_by&.id
          )

      unless membership&.customer_payment_management?
        raise Sales::InvalidCustomerPaymentError,
              "The user cannot record customer payments"
      end

      return if membership.branch_id.blank?
      return if membership.branch_id == sale.branch_id

      raise Sales::InvalidCustomerPaymentError,
            "The user cannot receive payment for this branch"
    end

    def validate_payment_method!
      valid =
        payment_method&.organization_id ==
          organization.id &&
        payment_method.active?

      return if valid

      raise Sales::InvalidCustomerPaymentError,
            "The selected payment method is unavailable"
    end

    def validate_money_account!
      valid =
        money_account&.organization_id ==
          organization.id &&
        money_account.active?

      return if valid

      raise Sales::InvalidCustomerPaymentError,
            "The selected money account is unavailable"
    end

    def validate_amounts!
      unless amount.positive?
        raise Sales::InvalidCustomerPaymentError,
              "Payment amount must be greater than zero"
      end

      unless amount == amount.round(2)
        raise Sales::InvalidCustomerPaymentError,
              "Payment amount cannot exceed two decimal places"
      end

      return if amount_tendered >= amount

      raise Sales::InvalidCustomerPaymentError,
            "Tendered amount must cover the payment amount"
    end

    def validate_outstanding_balance!
      unless sale.balance_due.positive?
        raise Sales::InvalidCustomerPaymentError,
              "This sale is already fully paid"
      end

      return if amount <= sale.balance_due

      raise Sales::InvalidCustomerPaymentError,
            "Payment cannot exceed the outstanding balance"
    end

    def create_payment!
      sale.sale_payments.create!(
        organization: organization,
        payment_method: payment_method,
        money_account: money_account,
        recorded_by: recorded_by,
        amount: money(amount),
        amount_tendered:
          money(amount_tendered),
        change_given:
          money(amount_tendered - amount),
        paid_at: paid_at || Time.current,
        reference: reference,
        notes: notes
      )
    end

    def update_sale_totals!
      new_amount_paid =
        money(
          sale.amount_paid + amount
        )

      new_balance =
        money(
          sale.total - new_amount_paid
        )

      sale.update!(
        amount_paid: new_amount_paid,
        balance_due: new_balance,
        payment_status:
          payment_status_for(
            amount_paid: new_amount_paid,
            balance_due: new_balance
          )
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

    def decimal_value(value, label:)
      BigDecimal(value.to_s)
    rescue ArgumentError, TypeError
      raise Sales::InvalidCustomerPaymentError,
            "Invalid #{label}"
    end

    def money(value)
      value.to_d.round(2)
    end
  end
end
