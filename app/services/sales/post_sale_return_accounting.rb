module Sales
  class PostSaleReturnAccounting
    def self.call(
      organization:,
      sale_return:
    )
      new(
        organization: organization,
        sale_return: sale_return
      ).call
    end

    def initialize(
      organization:,
      sale_return:
    )
      @organization = organization
      @sale_return = sale_return
    end

    def call
      validate_return!

      existing =
        existing_journal

      return existing if existing

      lines =
        journal_lines

      return nil if lines.empty?

      Accounting::CreateJournalEntry.call(
        organization: organization,
        created_by:
          sale_return.recorded_by,
        source: sale_return,
        entry_date:
          sale_return.returned_at.to_date,
        description:
          "Sales return #{sale_return.return_number}",
        lines: lines
      )
    rescue Accounting::AccountResolver::ConfigurationError,
           Accounting::PostJournalEntry::PostingError,
           Sales::CalculateReturnInventoryCost::CostError,
           ActiveRecord::RecordInvalid => error
      raise Sales::ReturnError,
            "Accounting posting failed: #{error.message}"
    end

    private

    attr_reader :organization,
                :sale_return

    def sale
      sale_return.sale
    end

    def existing_journal
      organization
        .journal_entries
        .find_by(
          source: sale_return
        )
    end

    def validate_return!
      unless sale_return&.persisted?
        raise Sales::ReturnError,
              "A saved sales return is required"
      end

      unless sale_return.organization_id ==
             organization.id
        raise Sales::ReturnError,
              "The sales return belongs to another organization"
      end

      unless sale_return.completed?
        raise Sales::ReturnError,
              "Only completed sales returns can be posted"
      end

      return if sale_return.returned_at.present?

      raise Sales::ReturnError,
            "Completed sales return has no return date"
    end

    def journal_lines
      lines = []

      append_sales_return_line!(
        lines
      )

      append_output_tax_line!(
        lines
      )

      append_settlement_lines!(
        lines
      )

      append_inventory_reversal_lines!(
        lines
      )

      lines
    end

    def append_sales_return_line!(lines)
      amount =
        sale_return.total.to_d -
        sale_return.tax_total.to_d

      return unless amount.positive?

      account =
        Accounting::AccountResolver.mapped!(
          organization: organization,
          role: "sales_returns"
        )

      lines << {
        ledger_account: account,
        branch: sale_return.branch,
        debit: amount,
        credit: 0,
        description:
          "Sales return #{sale_return.return_number}"
      }
    end

    def append_output_tax_line!(lines)
      amount =
        sale_return.tax_total.to_d

      return unless amount.positive?

      account =
        Accounting::AccountResolver.mapped!(
          organization: organization,
          role: "output_tax"
        )

      lines << {
        ledger_account: account,
        branch: sale_return.branch,
        debit: amount,
        credit: 0,
        description:
          "Output tax reversal for #{sale_return.return_number}"
      }
    end

    def append_settlement_lines!(lines)
      debt_offset =
        debt_offset_amount

      refund_liability =
        refund_liability_amount

      if debt_offset.positive?
        account =
          Accounting::AccountResolver.mapped!(
            organization: organization,
            role: "accounts_receivable"
          )

        lines << {
          ledger_account: account,
          branch: sale_return.branch,
          debit: 0,
          credit: debt_offset,
          description:
            "Reduce receivable for #{sale_return.return_number}"
        }
      end

      return unless refund_liability.positive?

      account =
        Accounting::AccountResolver.mapped!(
          organization: organization,
          role: "customer_refund_payable"
        )

      lines << {
        ledger_account: account,
        branch: sale_return.branch,
        debit: 0,
        credit: refund_liability,
        description:
          "Customer refund payable for #{sale_return.return_number}"
      }
    end

    def append_inventory_reversal_lines!(lines)
      cost =
        Sales::CalculateReturnInventoryCost.call(
          organization: organization,
          sale_return: sale_return
        )

      return unless cost.positive?

      inventory =
        Accounting::AccountResolver.mapped!(
          organization: organization,
          role: "inventory"
        )

      cogs =
        Accounting::AccountResolver.mapped!(
          organization: organization,
          role: "cost_of_goods_sold"
        )

      lines << {
        ledger_account: inventory,
        branch: sale_return.branch,
        debit: cost,
        credit: 0,
        description:
          "Inventory restored from #{sale_return.return_number}"
      }

      lines << {
        ledger_account: cogs,
        branch: sale_return.branch,
        debit: 0,
        credit: cost,
        description:
          "COGS reversal for #{sale_return.return_number}"
      }
    end

    def debt_offset_amount
      [
        sale_return.total.to_d,
        receivable_before_return
      ].min
    end

    def refund_liability_amount
      sale_return.total.to_d -
        debt_offset_amount
    end

    def receivable_before_return
      [
        sale.balance_due.to_d -
          prior_completed_return_total,
        0.to_d
      ].max
    end

    def prior_completed_return_total
      sale
        .sale_returns
        .completed
        .where.not(
          id: sale_return.id
        )
        .sum(:total)
        .to_d
    end
  end
end
