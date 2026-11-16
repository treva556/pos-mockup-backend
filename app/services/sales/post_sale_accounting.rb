module Sales
  class PostSaleAccounting
    def self.call(
      organization:,
      sale:
    )
      new(
        organization: organization,
        sale: sale
      ).call
    end

    def initialize(
      organization:,
      sale:
    )
      @organization =
        organization

      @sale =
        sale
    end

    def call
      validate_sale!

      existing =
        existing_journal

      return existing if existing

      return nil if sale.total.to_d.zero?

      validate_payment_total!

      Accounting::CreateJournalEntry.call(
        organization: organization,
        created_by: sale.cashier,
        source: sale,
        entry_date:
          sale.sold_at.to_date,
        description:
          "Sale #{sale.sale_number}",
        lines: journal_lines
      )
    rescue Accounting::AccountResolver::ConfigurationError,
           Accounting::PostJournalEntry::PostingError,
           Sales::CalculateInventoryCost::CostError,
           ActiveRecord::RecordInvalid => error
      raise Sales::CompletionError,
            "Accounting posting failed: #{error.message}"
    end

    private

    attr_reader :organization,
                :sale

    def existing_journal
      organization
        .journal_entries
        .find_by(
          source: sale
        )
    end

    def validate_sale!
      unless sale&.persisted?
        raise Sales::CompletionError,
              "A saved sale is required for accounting"
      end

      unless sale.organization_id ==
             organization.id
        raise Sales::CompletionError,
              "The sale belongs to another organization"
      end

      unless sale.completed?
        raise Sales::CompletionError,
              "Only completed sales can be posted to accounting"
      end

      return if sale.sold_at.present?

      raise Sales::CompletionError,
            "Completed sale has no sale date"
    end

    def validate_payment_total!
      recorded =
        sale
          .sale_payments
          .sum(
            :amount
          )
          .to_d
          .round(2)

      expected =
        sale
          .amount_paid
          .to_d
          .round(2)

      return if recorded == expected

      raise Sales::CompletionError,
            "Sale payments do not match the recorded amount paid"
    end

    def journal_lines
      lines = []

      append_payment_lines!(
        lines
      )

      append_receivable_line!(
        lines
      )

      append_revenue_line!(
        lines
      )

      append_tax_line!(
        lines
      )

      append_inventory_cost_lines!(
        lines
      )

      lines
    end

    def append_payment_lines!(lines)
      sale
        .sale_payments
        .oldest_first
        .includes(
          :money_account
        )
        .each do |payment|
          account =
            Accounting::AccountResolver.money!(
              organization: organization,
              money_account:
                payment.money_account
            )

          lines << {
            ledger_account: account,
            branch: sale.branch,
            debit: payment.amount.to_d,
            credit: 0,
            description:
              "Payment for #{sale.sale_number}"
          }
        end
    end

    def append_receivable_line!(lines)
      amount =
        sale.balance_due.to_d

      return unless amount.positive?

      account =
        Accounting::AccountResolver.mapped!(
          organization: organization,
          role: "accounts_receivable"
        )

      lines << {
        ledger_account: account,
        branch: sale.branch,
        debit: amount,
        credit: 0,
        description:
          "Receivable for #{sale.sale_number}"
      }
    end

    def append_revenue_line!(lines)
      amount =
        sale.total.to_d -
        sale.tax_total.to_d

      return unless amount.positive?

      account =
        Accounting::AccountResolver.mapped!(
          organization: organization,
          role: "sales_revenue"
        )

      lines << {
        ledger_account: account,
        branch: sale.branch,
        debit: 0,
        credit: amount,
        description:
          "Revenue from #{sale.sale_number}"
      }
    end

    def append_tax_line!(lines)
      amount =
        sale.tax_total.to_d

      return unless amount.positive?

      account =
        Accounting::AccountResolver.mapped!(
          organization: organization,
          role: "output_tax"
        )

      lines << {
        ledger_account: account,
        branch: sale.branch,
        debit: 0,
        credit: amount,
        description:
          "Output tax from #{sale.sale_number}"
      }
    end

    def append_inventory_cost_lines!(lines)
      cost =
        Sales::CalculateInventoryCost.call(
          organization: organization,
          sale: sale
        )

      return unless cost.positive?

      cogs_account =
        Accounting::AccountResolver.mapped!(
          organization: organization,
          role: "cost_of_goods_sold"
        )

      inventory_account =
        Accounting::AccountResolver.mapped!(
          organization: organization,
          role: "inventory"
        )

      lines << {
        ledger_account: cogs_account,
        branch: sale.branch,
        debit: cost,
        credit: 0,
        description:
          "Cost of goods sold for #{sale.sale_number}"
      }

      lines << {
        ledger_account: inventory_account,
        branch: sale.branch,
        debit: 0,
        credit: cost,
        description:
          "Inventory sold through #{sale.sale_number}"
      }
    end
  end
end
