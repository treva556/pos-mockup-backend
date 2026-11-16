module Purchases
  class PostSupplierPaymentAccounting
    def self.call(
      organization:,
      payment:
    )
      new(
        organization: organization,
        payment: payment
      ).call
    end

    def initialize(
      organization:,
      payment:
    )
      @organization =
        organization

      @payment =
        payment
    end

    def call
      validate_payment!

      existing =
        existing_journal

      return existing if existing

      Accounting::CreateJournalEntry.call(
        organization: organization,
        created_by:
          payment.recorded_by,
        source: payment,
        entry_date:
          payment.paid_at.to_date,
        description:
          "Supplier payment for #{purchase.purchase_number}",
        lines: journal_lines
      )
    rescue Accounting::AccountResolver::ConfigurationError,
           Accounting::PostJournalEntry::PostingError,
           ActiveRecord::RecordInvalid => error
      raise Purchases::InvalidSupplierPaymentError,
            "Accounting posting failed: #{error.message}"
    end

    private

    attr_reader :organization,
                :payment

    def purchase
      payment.purchase
    end

    def existing_journal
      organization
        .journal_entries
        .find_by(
          source: payment
        )
    end

    def validate_payment!
      unless payment&.persisted?
        raise Purchases::InvalidSupplierPaymentError,
              "A saved supplier payment is required"
      end

      unless payment.organization_id ==
             organization.id
        raise Purchases::InvalidSupplierPaymentError,
              "The supplier payment belongs to another organization"
      end

      unless purchase.received?
        raise Purchases::InvalidSupplierPaymentError,
              "Only received purchases can be paid"
      end

      return if payment.amount.to_d.positive?

      raise Purchases::InvalidSupplierPaymentError,
            "Supplier payment must be greater than zero"
    end

    def journal_lines
      [
        {
          ledger_account:
            accounts_payable,
          branch:
            purchase.branch,
          debit:
            payment.amount.to_d,
          credit: 0,
          description:
            "Reduce payable for #{purchase.purchase_number}"
        },
        {
          ledger_account:
            money_account,
          branch:
            purchase.branch,
          debit: 0,
          credit:
            payment.amount.to_d,
          description:
            "Supplier payment for #{purchase.purchase_number}"
        }
      ]
    end

    def accounts_payable
      Accounting::AccountResolver.mapped!(
        organization: organization,
        role: "accounts_payable"
      )
    end

    def money_account
      Accounting::AccountResolver.money!(
        organization: organization,
        money_account:
          payment.money_account
      )
    end
  end
end
