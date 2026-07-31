require "securerandom"

module Sales
  class PaymentPlan
    Entry =
      Struct.new(
        :id,
        :payment_method,
        :money_account,
        :amount,
        :amount_tendered,
        :change_given,
        :reference,
        :notes,
        keyword_init: true
      )

    def initialize(
      organization:,
      branch:,
      sale_total:,
      data: nil
    )
      @organization = organization
      @branch = branch
      @sale_total = sale_total.to_d
      @data =
        (data || {})
          .deep_stringify_keys

      validate_sale_total!
    end

    attr_reader :organization,
                :branch,
                :sale_total

    def entries
      @entries ||= load_entries
    end

    def empty?
      entries.empty?
    end

    def entry_count
      entries.length
    end

    def add_entry(
      payment_method_id:,
      money_account_id:,
      amount:,
      amount_tendered: nil,
      reference: nil,
      notes: nil
    )
      entry_id = SecureRandom.uuid

      mutate! do
        raw_entries[entry_id] =
          build_entry_payload(
            payment_method_id: payment_method_id,
            money_account_id: money_account_id,
            amount: amount,
            amount_tendered: amount_tendered,
            reference: reference,
            notes: notes
          )
      end

      entry_id
    end

    def update_entry(
      entry_id:,
      payment_method_id:,
      money_account_id:,
      amount:,
      amount_tendered: nil,
      reference: nil,
      notes: nil
    )
      key = entry_id.to_s

      unless raw_entries.key?(key)
        raise Sales::InvalidPaymentError,
              "The selected payment is no longer available"
      end

      mutate! do
        raw_entries[key] =
          build_entry_payload(
            payment_method_id: payment_method_id,
            money_account_id: money_account_id,
            amount: amount,
            amount_tendered: amount_tendered,
            reference: reference,
            notes: notes
          )
      end
    end

    def remove_entry(entry_id:)
      raw_entries.delete(entry_id.to_s)
      reset_entries!
    end

    def clear!
      data["entries"] = {}
      reset_entries!
    end

    def applied_total
      entries.sum(0.to_d, &:amount)
    end

    def tendered_total
      entries.sum(
        0.to_d,
        &:amount_tendered
      )
    end

    def change_total
      entries.sum(
        0.to_d,
        &:change_given
      )
    end

    def balance_due
      sale_total - applied_total
    end

    def payment_status
      return "paid" if balance_due.zero?
      return "unpaid" if applied_total.zero?

      "partially_paid"
    end

    def credit_sale?
      balance_due.positive?
    end

    def ready_for_completion?(customer:)
      return true if balance_due.zero?

      customer.present?
    end

    def to_session
      {
        "entries" => raw_entries.deep_dup
      }
    end

    private

    attr_reader :data

    def raw_entries
      data["entries"] ||= {}
    end

    def load_entries
      raw_entries.map do |entry_id, attributes|
        payment_method =
          find_payment_method!(
            attributes["payment_method_id"]
          )

        money_account =
          find_money_account!(
            attributes["money_account_id"]
          )

        amount =
          decimal_value(
            attributes["amount"],
            field: "payment amount"
          )

        amount_tendered =
          decimal_value(
            attributes["amount_tendered"],
            field: "tendered amount"
          )

        validate_amounts!(
          amount: amount,
          amount_tendered: amount_tendered
        )

        Entry.new(
          id: entry_id,
          payment_method: payment_method,
          money_account: money_account,
          amount: amount,
          amount_tendered: amount_tendered,
          change_given:
            amount_tendered - amount,
          reference:
            attributes["reference"].presence,
          notes:
            attributes["notes"].presence
        )
      end
    end

    def build_entry_payload(
      payment_method_id:,
      money_account_id:,
      amount:,
      amount_tendered:,
      reference:,
      notes:
    )
      payment_method =
        find_payment_method!(
          payment_method_id
        )

      money_account =
        find_money_account!(
          money_account_id
        )

      applied_amount =
        decimal_value(
          amount,
          field: "payment amount"
        )

      tendered_amount =
        if amount_tendered.present?
          decimal_value(
            amount_tendered,
            field: "tendered amount"
          )
        else
          applied_amount
        end

      validate_amounts!(
        amount: applied_amount,
        amount_tendered: tendered_amount
      )

      {
        "payment_method_id" =>
          payment_method.id,
        "money_account_id" =>
          money_account.id,
        "amount" =>
          applied_amount.to_s("F"),
        "amount_tendered" =>
          tendered_amount.to_s("F"),
        "reference" =>
          normalize_text(reference),
        "notes" =>
          normalize_text(notes)
      }
    end

    def find_payment_method!(id)
      payment_method =
        organization
          .payment_methods
          .find(id)

      ensure_active!(
        payment_method,
        label: "payment method"
      )

      payment_method
    rescue ActiveRecord::RecordNotFound
      raise Sales::InvalidPaymentError,
            "The selected payment method is unavailable"
    end

    def find_money_account!(id)
      money_account =
        organization
          .money_accounts
          .find(id)

      ensure_active!(
        money_account,
        label: "money account"
      )

      money_account
    rescue ActiveRecord::RecordNotFound
      raise Sales::InvalidPaymentError,
            "The selected money account is unavailable"
    end

    def ensure_active!(record, label:)
      return unless record.respond_to?(:active?)
      return if record.active?

      raise Sales::InvalidPaymentError,
            "The selected #{label} is inactive"
    end

    def validate_amounts!(
      amount:,
      amount_tendered:
    )
      unless amount.positive?
        raise Sales::InvalidPaymentError,
              "Payment amount must be greater than zero"
      end

      return if amount_tendered >= amount

      raise Sales::InvalidPaymentError,
            "Tendered amount must cover the payment amount"
    end

    def validate_sale_total!
      return unless sale_total.negative?

      raise Sales::InvalidPaymentError,
            "Sale total cannot be negative"
    end

    def validate_plan_total!
      return if applied_total <= sale_total

      raise Sales::InvalidPaymentError,
            "Applied payments cannot exceed the sale total"
    end

    def mutate!
      previous_data = data.deep_dup

      yield

      reset_entries!
      validate_plan_total!

      self
    rescue StandardError
      @data = previous_data
      reset_entries!
      raise
    end

    def reset_entries!
      @entries = nil
    end

    def decimal_value(value, field:)
      BigDecimal(value.to_s)
    rescue ArgumentError, TypeError
      raise Sales::InvalidPaymentError,
            "Invalid #{field}"
    end

    def normalize_text(value)
      value.to_s.strip.presence
    end
  end
end
