module Sales
  class PostCustomerRefundAccounting
    def self.call(
      organization:,
      refund:
    )
      new(
        organization: organization,
        refund: refund
      ).call
    end

    def initialize(
      organization:,
      refund:
    )
      @organization = organization
      @refund = refund
    end

    def call
      validate_refund!

      existing =
        existing_journal

      return existing if existing

      Accounting::CreateJournalEntry.call(
        organization: organization,
        created_by:
          refund.recorded_by,
        source: refund,
        entry_date:
          refund.refunded_at.to_date,
        description:
          "Customer refund for #{sale_return.return_number}",
        lines: journal_lines
      )
    rescue Accounting::AccountResolver::ConfigurationError,
           Accounting::PostJournalEntry::PostingError,
           ActiveRecord::RecordInvalid => error
      raise Sales::RefundError,
            "Accounting posting failed: #{error.message}"
    end

    private

    attr_reader :organization,
                :refund

    def sale_return
      refund.sale_return
    end

    def existing_journal
      organization
        .journal_entries
        .find_by(
          source: refund
        )
    end

    def validate_refund!
      unless refund&.persisted?
        raise Sales::RefundError,
              "A saved customer refund is required"
      end

      unless refund.organization_id ==
             organization.id
        raise Sales::RefundError,
              "The refund belongs to another organization"
      end

      unless sale_return.completed?
        raise Sales::RefundError,
              "The sales return is not completed"
      end

      return if refund.amount.to_d.positive?

      raise Sales::RefundError,
            "Refund amount must be greater than zero"
    end

    def journal_lines
      [
        {
          ledger_account:
            refund_payable_account,
          branch:
            sale_return.branch,
          debit:
            refund.amount.to_d,
          credit: 0,
          description:
            "Settle refund #{sale_return.return_number}"
        },
        {
          ledger_account:
            money_ledger_account,
          branch:
            sale_return.branch,
          debit: 0,
          credit:
            refund.amount.to_d,
          description:
            "Customer refund #{sale_return.return_number}"
        }
      ]
    end

    def refund_payable_account
      Accounting::AccountResolver.mapped!(
        organization: organization,
        role: "customer_refund_payable"
      )
    end

    def money_ledger_account
      Accounting::AccountResolver.money!(
        organization: organization,
        money_account:
          refund.money_account
      )
    end
  end
end
