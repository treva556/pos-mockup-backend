module Purchases
  class PostPurchaseReturnAccounting
    def self.call(
      organization:,
      purchase_return:
    )
      new(
        organization: organization,
        purchase_return: purchase_return
      ).call
    end

    def initialize(
      organization:,
      purchase_return:
    )
      @organization = organization
      @purchase_return = purchase_return
    end

    def call
      validate_return!

      existing =
        existing_journal

      return existing if existing
      return nil if purchase_return.total.to_d.zero?

      validate_settlement!

      Accounting::CreateJournalEntry.call(
        organization: organization,
        created_by:
          purchase_return.recorded_by,
        source:
          purchase_return,
        entry_date:
          purchase_return.returned_at.to_date,
        description:
          "Purchase return #{purchase_return.return_number}",
        lines:
          journal_lines
      )
    rescue Accounting::AccountResolver::ConfigurationError,
           Accounting::PostJournalEntry::PostingError,
           ActiveRecord::RecordInvalid => error
      raise Purchases::ReturnError,
            "Accounting posting failed: #{error.message}"
    end

    private

    attr_reader :organization,
                :purchase_return

    def existing_journal
      organization
        .journal_entries
        .find_by(
          source: purchase_return
        )
    end

    def validate_return!
      unless purchase_return&.persisted?
        raise Purchases::ReturnError,
              "A saved purchase return is required for accounting"
      end

      unless purchase_return.organization_id ==
             organization.id
        raise Purchases::ReturnError,
              "The purchase return belongs to another organization"
      end

      unless purchase_return.completed?
        raise Purchases::ReturnError,
              "Only completed purchase returns can be posted"
      end

      return if purchase_return.returned_at.present?

      raise Purchases::ReturnError,
            "Completed purchase return has no return date"
    end

    def validate_settlement!
      settlement =
        debt_offset_amount +
        supplier_credit_amount

      expected =
        purchase_return.total.to_d

      return if settlement == expected

      raise Purchases::ReturnError,
            "Purchase return settlement does not match its total"
    end

    def journal_lines
      lines = []

      append_accounts_payable_line!(
        lines
      )

      append_supplier_credit_line!(
        lines
      )

      append_inventory_line!(
        lines
      )

      append_input_tax_line!(
        lines
      )

      lines
    end

    def append_accounts_payable_line!(lines)
      amount =
        debt_offset_amount

      return unless amount.positive?

      account =
        Accounting::AccountResolver.mapped!(
          organization: organization,
          role: "accounts_payable"
        )

      lines << {
        ledger_account: account,
        branch:
          purchase_return.branch,
        debit: amount,
        credit: 0,
        description:
          "Reduce payable for #{purchase_return.return_number}"
      }
    end

    def append_supplier_credit_line!(lines)
      amount =
        supplier_credit_amount

      return unless amount.positive?

      account =
        Accounting::AccountResolver.mapped!(
          organization: organization,
          role: "supplier_credit_receivable"
        )

      lines << {
        ledger_account: account,
        branch:
          purchase_return.branch,
        debit: amount,
        credit: 0,
        description:
          "Supplier credit due for #{purchase_return.return_number}"
      }
    end

    def append_inventory_line!(lines)
      amount =
        purchase_return.total.to_d -
        purchase_return.tax_total.to_d

      return unless amount.positive?

      account =
        Accounting::AccountResolver.mapped!(
          organization: organization,
          role: "inventory"
        )

      lines << {
        ledger_account: account,
        branch:
          purchase_return.branch,
        debit: 0,
        credit: amount,
        description:
          "Inventory returned through #{purchase_return.return_number}"
      }
    end

    def append_input_tax_line!(lines)
      amount =
        purchase_return.tax_total.to_d

      return unless amount.positive?

      account =
        Accounting::AccountResolver.mapped!(
          organization: organization,
          role: "input_tax"
        )

      lines << {
        ledger_account: account,
        branch:
          purchase_return.branch,
        debit: 0,
        credit: amount,
        description:
          "Input tax reversal for #{purchase_return.return_number}"
      }
    end

    def debt_offset_amount
      purchase_return
        .debt_offset_amount
        .to_d
    end

    def supplier_credit_amount
      purchase_return
        .supplier_credit_due
        .to_d
    end
  end
end
