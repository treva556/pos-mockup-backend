module Purchases
  class RecordSupplierCredit
    def self.call(...)
      new(...).call
    end

    def initialize(
      organization:,
      purchase_return:,
      recorded_by:,
      amount:,
      credit_number:,
      issued_on:,
      notes: nil
    )
      @organization = organization
      @purchase_return = purchase_return
      @recorded_by = recorded_by

      @amount =
        decimal_value(
          amount,
          label: "supplier credit amount"
        )

      @credit_number =
        credit_number
          .to_s
          .strip
          .upcase

      @issued_on =
        ActiveModel::Type::Date
          .new
          .cast(issued_on)

      @notes =
        notes
          .to_s
          .strip
          .presence
    end

    def call
      validate_context!

      SupplierCredit.transaction do
        purchase_return.lock!
        purchase_return.reload

        validate_locked_return!

        purchase_return
          .supplier_credits
          .create!(
            organization: organization,
            recorded_by: recorded_by,
            amount: money(amount),
            applied_amount: 0,
            credit_number:
              credit_number,
            issued_on:
              issued_on,
            status: "available",
            notes: notes
          )
      end
    rescue ActiveRecord::RecordInvalid => error
      message =
        error
          .record
          .errors
          .full_messages
          .to_sentence

      raise Purchases::SupplierCreditError,
            message.presence || error.message
    end

    private

    attr_reader :organization,
                :purchase_return,
                :recorded_by,
                :amount,
                :credit_number,
                :issued_on,
                :notes

    def validate_context!
      unless organization&.persisted?
        raise Purchases::SupplierCreditError,
              "A saved organization is required"
      end

      unless purchase_return&.organization_id ==
             organization.id
        raise Purchases::SupplierCreditError,
              "The purchase return belongs to another organization"
      end

      validate_member!

      unless amount.positive?
        raise Purchases::SupplierCreditError,
              "Supplier credit amount must be greater than zero"
      end

      unless amount == money(amount)
        raise Purchases::SupplierCreditError,
              "Supplier credit amount cannot have more than two decimals"
      end

      if credit_number.blank?
        raise Purchases::SupplierCreditError,
              "Enter the supplier credit number"
      end

      return if issued_on.present?

      raise Purchases::SupplierCreditError,
            "Enter the supplier credit issue date"
    end

    def validate_member!
      membership =
        organization
          .memberships
          .active
          .find_by(
            user_id: recorded_by&.id
          )

      unless membership&.supplier_credit_management?
        raise Purchases::SupplierCreditError,
              "The user cannot record supplier credits"
      end

      return if membership.branch_id.blank?

      return if membership.branch_id ==
                purchase_return.branch_id

      raise Purchases::SupplierCreditError,
            "The user cannot record credits for this branch"
    end

    def validate_locked_return!
      unless purchase_return.completed?
        raise Purchases::SupplierCreditError,
              "Only completed purchase returns can create supplier credit"
      end

      available =
        purchase_return
          .uncredited_balance

      unless available.positive?
        raise Purchases::SupplierCreditError,
              "This return has no supplier credit outstanding"
      end

      return if amount <= available

      raise Purchases::SupplierCreditError,
            "Supplier credit cannot exceed " \
            "KSh #{money(available)}"
    end

    def decimal_value(value, label:)
      BigDecimal(value.to_s)
    rescue ArgumentError, TypeError
      raise Purchases::SupplierCreditError,
            "Invalid #{label}"
    end

    def money(value)
      value.to_d.round(2)
    end
  end
end
