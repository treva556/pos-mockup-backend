module Sales
  class RecordCustomerRefund
    def self.call(...)
      new(...).call
    end

    def initialize(
      organization:,
      sale_return:,
      recorded_by:,
      payment_method:,
      money_account:,
      amount:,
      refunded_at: Time.current,
      reference: nil,
      notes: nil
    )
      @organization = organization
      @sale_return = sale_return
      @recorded_by = recorded_by
      @payment_method = payment_method
      @money_account = money_account

      @amount =
        decimal_value(
          amount,
          label: "refund amount"
        )

      @refunded_at =
        ActiveModel::Type::DateTime
          .new
          .cast(refunded_at)

      @reference = reference
      @notes = notes
    end

    def call
      validate_context!

      Sale.transaction do
        sale.with_lock do
          money_account.with_lock do
            sale.reload
            sale_return.reload
            money_account.reload

            validate_refundable_amount!
            validate_account_balance!

            create_refund!
          end
        end
      end
    rescue ActiveRecord::RecordInvalid => error
      raise Sales::RefundError,
            error.record.errors
              .full_messages
              .to_sentence
    end

    private

    attr_reader :organization,
                :sale_return,
                :recorded_by,
                :payment_method,
                :money_account,
                :amount,
                :refunded_at,
                :reference,
                :notes

    def sale
      sale_return.sale
    end

    def validate_context!
      unless organization&.persisted?
        raise Sales::RefundError,
              "A saved organization is required"
      end

      unless sale_return&.persisted? &&
             sale_return.organization_id ==
               organization.id
        raise Sales::RefundError,
              "The sales return is invalid"
      end

      unless sale_return.completed?
        raise Sales::RefundError,
              "Only completed returns can be refunded"
      end

      validate_member!
      validate_payment_method!
      validate_money_account!
      validate_amount!
    end

    def validate_member!
      membership =
        organization
          .memberships
          .active
          .find_by(
            user_id: recorded_by&.id
          )

      unless membership&.customer_refund_management?
        raise Sales::RefundError,
              "The user cannot issue customer refunds"
      end

      return if membership.branch_id.blank?

      return if membership.branch_id ==
                sale_return.branch_id

      raise Sales::RefundError,
            "The user cannot refund this branch"
    end

    def validate_payment_method!
      valid =
        payment_method&.organization_id ==
            organization.id &&
        payment_method.active?

      return if valid

      raise Sales::RefundError,
            "The selected payment method is unavailable"
    end

    def validate_money_account!
      valid =
        money_account&.organization_id ==
            organization.id &&
        money_account.active? &&
        money_account.can_pay?

      unless valid
        raise Sales::RefundError,
              "The selected money account cannot issue refunds"
      end

      return if
        money_account.branch_id.blank?

      return if
        money_account.branch_id ==
          sale_return.branch_id

      raise Sales::RefundError,
            "The money account belongs to another branch"
    end

    def validate_amount!
      unless amount.positive?
        raise Sales::RefundError,
              "Refund amount must be greater than zero"
      end

      return if amount ==
                amount.round(2)

      raise Sales::RefundError,
            "Refund amount cannot exceed two decimal places"
    end

    def validate_refundable_amount!
      available =
        sale.available_return_refund

      unless available.positive?
        raise Sales::RefundError,
              "There is no refundable balance for this sale"
      end

      return if amount <= available

      raise Sales::RefundError,
            "Refund cannot exceed " \
            "#{available.to_s('F')}"
    end

    def validate_account_balance!
      available =
        money_account.current_balance.to_d

      return if amount <= available

      raise Sales::RefundError,
            "The selected money account has " \
            "insufficient funds"
    end

    def create_refund!
      sale_return
        .customer_refunds
        .create!(
          organization: organization,
          payment_method:
            payment_method,
          money_account:
            money_account,
          recorded_by:
            recorded_by,
          amount:
            money(amount),
          refunded_at:
            refunded_at ||
              Time.current,
          reference: reference,
          notes: notes
        )
    end

    def decimal_value(
      value,
      label:
    )
      BigDecimal(value.to_s)
    rescue ArgumentError,
           TypeError
      raise Sales::RefundError,
            "Invalid #{label}"
    end

    def money(value)
      value.to_d.round(2)
    end
  end
end
