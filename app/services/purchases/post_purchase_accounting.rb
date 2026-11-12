module Purchases
  class PostPurchaseAccounting
    def self.call(
      organization:,
      purchase:
    )
      new(
        organization: organization,
        purchase: purchase
      ).call
    end

    def initialize(
      organization:,
      purchase:
    )
      @organization =
        organization

      @purchase =
        purchase
    end

    def call
      validate_purchase!

      existing =
        existing_journal

      return existing if existing
      return nil if purchase.total.to_d.zero?

      Accounting::CreateJournalEntry.call(
        organization: organization,
        created_by:
          purchase.recorded_by,
        source: purchase,
        entry_date:
          purchase.purchased_on,
        description:
          "Purchase #{purchase.purchase_number}",
        lines: journal_lines
      )
    rescue Accounting::AccountResolver::ConfigurationError,
           Accounting::PostJournalEntry::PostingError,
           ActiveRecord::RecordInvalid => error
      raise Purchases::ReceivingError,
            "Accounting posting failed: #{error.message}"
    end

    private

    attr_reader :organization,
                :purchase

    def existing_journal
      organization
        .journal_entries
        .find_by(
          source: purchase
        )
    end

    def validate_purchase!
      unless purchase&.persisted?
        raise Purchases::ReceivingError,
              "A saved purchase is required for accounting"
      end

      unless purchase.organization_id ==
             organization.id
        raise Purchases::ReceivingError,
              "The purchase belongs to another organization"
      end

      return if purchase.received?

      raise Purchases::ReceivingError,
            "Only received purchases can be posted to accounting"
    end

    def journal_lines
      lines = []

      append_inventory_line!(
        lines
      )

      append_input_tax_line!(
        lines
      )

      append_payable_line!(
        lines
      )

      lines
    end

    def append_inventory_line!(lines)
      amount =
        purchase.total.to_d -
        purchase.tax_total.to_d

      return unless amount.positive?

      account =
        Accounting::AccountResolver.mapped!(
          organization: organization,
          role: "inventory"
        )

      lines << {
        ledger_account: account,
        branch: purchase.branch,
        debit: amount,
        credit: 0,
        description:
          "Inventory received through #{purchase.purchase_number}"
      }
    end

    def append_input_tax_line!(lines)
      amount =
        purchase.tax_total.to_d

      return unless amount.positive?

      account =
        Accounting::AccountResolver.mapped!(
          organization: organization,
          role: "input_tax"
        )

      lines << {
        ledger_account: account,
        branch: purchase.branch,
        debit: amount,
        credit: 0,
        description:
          "Input tax on #{purchase.purchase_number}"
      }
    end

    def append_payable_line!(lines)
      account =
        Accounting::AccountResolver.mapped!(
          organization: organization,
          role: "accounts_payable"
        )

      lines << {
        ledger_account: account,
        branch: purchase.branch,
        debit: 0,
        credit:
          purchase.total.to_d,
        description:
          "Payable for #{purchase.purchase_number}"
      }
    end
  end
end
