module Purchases
  class RecordSupplierPayment
    def self.call(...)
      new(...).call
    end

    def initialize(
      organization:,
      purchase:,
      payment_method:,
      money_account:,
      recorded_by:,
      amount:,
      paid_at: Time.current,
      reference: nil,
      notes: nil
    )
      @organization = organization
      @purchase = purchase
      @payment_method = payment_method
      @money_account = money_account
      @recorded_by = recorded_by
      @amount = amount.to_d
      @paid_at = paid_at || Time.current
      @reference = reference.to_s.strip.presence
      @notes = notes.to_s.strip.presence
    end

    def call
      validate_context!

      PurchasePayment.transaction do
        purchase.lock!
        money_account.lock!

        validate_locked_purchase!
        validate_available_money!

        payment =
          purchase.purchase_payments.create!(
            organization: organization,
            payment_method: payment_method,
            money_account: money_account,
            recorded_by: recorded_by,
            amount: money(amount),
            paid_at: paid_at,
            reference: reference,
            notes: notes
          )

        refresh_purchase_totals!

        payment
      end
    end

    private

    attr_reader :organization,
                :purchase,
                :payment_method,
                :money_account,
                :recorded_by,
                :amount,
                :paid_at,
                :reference,
                :notes

    def validate_context!
      unless organization&.persisted?
        raise Purchases::InvalidSupplierPaymentError,
              "A saved organization is required"
      end

      unless purchase&.organization_id ==
             organization.id
        raise Purchases::InvalidSupplierPaymentError,
              "The purchase belongs to another organization"
      end

      unless payment_method&.organization_id ==
             organization.id
        raise Purchases::InvalidSupplierPaymentError,
              "The payment method belongs to another organization"
      end

      unless money_account&.organization_id ==
             organization.id
        raise Purchases::InvalidSupplierPaymentError,
              "The money account belongs to another organization"
      end

      membership =
        organization
          .memberships
          .active
          .find_by(
            user_id: recorded_by&.id
          )

      unless membership&.supplier_payment_management?
        raise Purchases::InvalidSupplierPaymentError,
              "The user cannot record supplier payments"
      end

      if membership.branch_id.present? &&
         membership.branch_id != purchase.branch_id
        raise Purchases::InvalidSupplierPaymentError,
              "The user cannot pay purchases from this branch"
      end

      unless amount.positive?
        raise Purchases::InvalidSupplierPaymentError,
              "Payment amount must be greater than zero"
      end

      return if amount == money(amount)

      raise Purchases::InvalidSupplierPaymentError,
            "Payment amount cannot have more than two decimals"
    end

    def validate_locked_purchase!
      unless purchase.received?
        raise Purchases::InvalidSupplierPaymentError,
              "Only received purchases can be paid"
      end

      if purchase.balance_due.to_d.zero?
        raise Purchases::InvalidSupplierPaymentError,
              "This purchase is already fully paid"
      end

      return if amount <= purchase.balance_due.to_d

      raise Purchases::InvalidSupplierPaymentError,
            "Payment cannot exceed the outstanding balance"
    end

    def validate_available_money!
      available =
        money_account.current_balance.to_d

      return if available >= amount

      raise Purchases::InvalidSupplierPaymentError,
            "#{money_account.name} only has " \
            "KSh #{money(available)} available"
    end

    def refresh_purchase_totals!
      amount_paid =
        money(
          purchase
            .purchase_payments
            .sum(:amount)
        )

      balance_due =
        money(
          purchase.total.to_d -
            amount_paid
        )

      purchase.update!(
        amount_paid: amount_paid,
        balance_due: balance_due,
        payment_status:
          payment_status_for(
            amount_paid: amount_paid,
            balance_due: balance_due
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

    def money(value)
      value.to_d.round(2)
    end
  end
end
