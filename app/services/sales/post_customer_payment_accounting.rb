module Sales
  class PostCustomerPaymentAccounting
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
          "Customer payment for #{sale.sale_number}",
        lines: journal_lines
      )
    rescue Accounting::AccountResolver::ConfigurationError,
           Accounting::PostJournalEntry::PostingError,
           ActiveRecord::RecordInvalid => error
      raise Sales::InvalidCustomerPaymentError,
            "Accounting posting failed: #{error.message}"
    end

    private

    attr_reader :organization,
                :payment

    def sale
      payment.sale
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
        raise Sales::InvalidCustomerPaymentError,
              "A saved customer payment is required"
      end

      unless payment.organization_id ==
             organization.id
        raise Sales::InvalidCustomerPaymentError,
              "The payment belongs to another organization"
      end

      unless sale.organization_id ==
             organization.id
        raise Sales::InvalidCustomerPaymentError,
              "The sale belongs to another organization"
      end

      unless sale.completed?
        raise Sales::InvalidCustomerPaymentError,
              "Only completed sales can receive accounting payments"
      end

      unless payment.amount.to_d.positive?
        raise Sales::InvalidCustomerPaymentError,
              "Payment amount must be greater than zero"
      end

      return if payment.paid_at.present?

      raise Sales::InvalidCustomerPaymentError,
            "Customer payment has no payment date"
    end

    def journal_lines
      [
        {
          ledger_account:
            money_ledger_account,
          branch:
            sale.branch,
          debit:
            payment.amount.to_d,
          credit: 0,
          description:
            "Receipt for #{sale.sale_number}"
        },
        {
          ledger_account:
            accounts_receivable,
          branch:
            sale.branch,
          debit: 0,
          credit:
            payment.amount.to_d,
          description:
            "Reduce receivable for #{sale.sale_number}"
        }
      ]
    end

    def money_ledger_account
      Accounting::AccountResolver.money!(
        organization: organization,
        money_account:
          payment.money_account
      )
    end

    def accounts_receivable
      Accounting::AccountResolver.mapped!(
        organization: organization,
        role: "accounts_receivable"
      )
    end
  end
end
