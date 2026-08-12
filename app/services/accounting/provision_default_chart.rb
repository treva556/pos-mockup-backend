module Accounting
  class ProvisionDefaultChart
    ACCOUNTS = [
      {
        code: "1000",
        name: "Assets",
        account_type: "asset",
        normal_balance: "debit",
        report_group: "current_asset",
        postable: false,
        system_account: true
      },
      {
        code: "1010",
        name: "Cash and Cash Equivalents",
        parent_code: "1000",
        account_type: "asset",
        normal_balance: "debit",
        report_group: "current_asset",
        postable: false,
        system_account: true
      },
      {
        code: "1100",
        name: "Accounts Receivable",
        parent_code: "1000",
        account_type: "asset",
        normal_balance: "debit",
        report_group: "current_asset",
        postable: true,
        system_account: true
      },
      {
        code: "1200",
        name: "Inventory",
        parent_code: "1000",
        account_type: "asset",
        normal_balance: "debit",
        report_group: "current_asset",
        postable: true,
        system_account: true
      },
      {
        code: "1300",
        name: "Supplier Credits Receivable",
        parent_code: "1000",
        account_type: "asset",
        normal_balance: "debit",
        report_group: "current_asset",
        postable: true,
        system_account: true
      },
      {
        code: "1400",
        name: "Input Tax Recoverable",
        parent_code: "1000",
        account_type: "asset",
        normal_balance: "debit",
        report_group: "current_asset",
        postable: true,
        system_account: true
      },

      {
        code: "2000",
        name: "Liabilities",
        account_type: "liability",
        normal_balance: "credit",
        report_group: "current_liability",
        postable: false,
        system_account: true
      },
      {
        code: "2010",
        name: "Accounts Payable",
        parent_code: "2000",
        account_type: "liability",
        normal_balance: "credit",
        report_group: "current_liability",
        postable: true,
        system_account: true
      },
      {
        code: "2020",
        name: "Customer Refunds Payable",
        parent_code: "2000",
        account_type: "liability",
        normal_balance: "credit",
        report_group: "current_liability",
        postable: true,
        system_account: true
      },
      {
        code: "2100",
        name: "Output Tax Payable",
        parent_code: "2000",
        account_type: "liability",
        normal_balance: "credit",
        report_group: "current_liability",
        postable: true,
        system_account: true
      },

      {
        code: "3000",
        name: "Equity",
        account_type: "equity",
        normal_balance: "credit",
        report_group: "equity",
        postable: false,
        system_account: true
      },
      {
        code: "3010",
        name: "Owner's Capital",
        parent_code: "3000",
        account_type: "equity",
        normal_balance: "credit",
        report_group: "equity",
        postable: true,
        system_account: false
      },
      {
        code: "3090",
        name: "Opening Balance Equity",
        parent_code: "3000",
        account_type: "equity",
        normal_balance: "credit",
        report_group: "equity",
        postable: true,
        system_account: true
      },
      {
        code: "3100",
        name: "Retained Earnings",
        parent_code: "3000",
        account_type: "equity",
        normal_balance: "credit",
        report_group: "equity",
        postable: true,
        system_account: true
      },

      {
        code: "4000",
        name: "Revenue",
        account_type: "revenue",
        normal_balance: "credit",
        report_group: "revenue",
        postable: false,
        system_account: true
      },
      {
        code: "4010",
        name: "Sales Revenue",
        parent_code: "4000",
        account_type: "revenue",
        normal_balance: "credit",
        report_group: "revenue",
        postable: true,
        system_account: true
      },
      {
        code: "4090",
        name: "Sales Returns and Allowances",
        parent_code: "4000",
        account_type: "revenue",
        normal_balance: "debit",
        report_group: "contra_revenue",
        postable: true,
        system_account: true
      },
      {
        code: "4900",
        name: "Inventory Adjustment Gain",
        parent_code: "4000",
        account_type: "revenue",
        normal_balance: "credit",
        report_group: "other_income",
        postable: true,
        system_account: true
      },

      {
        code: "5000",
        name: "Cost of Sales",
        account_type: "expense",
        normal_balance: "debit",
        report_group: "cost_of_sales",
        postable: false,
        system_account: true
      },
      {
        code: "5010",
        name: "Cost of Goods Sold",
        parent_code: "5000",
        account_type: "expense",
        normal_balance: "debit",
        report_group: "cost_of_sales",
        postable: true,
        system_account: true
      },
      {
        code: "5090",
        name: "Inventory Adjustment Loss",
        parent_code: "5000",
        account_type: "expense",
        normal_balance: "debit",
        report_group: "cost_of_sales",
        postable: true,
        system_account: true
      },

      {
        code: "6000",
        name: "Operating Expenses",
        account_type: "expense",
        normal_balance: "debit",
        report_group: "operating_expense",
        postable: false,
        system_account: true
      },
      {
        code: "6010",
        name: "Rent Expense",
        parent_code: "6000",
        account_type: "expense",
        normal_balance: "debit",
        report_group: "operating_expense",
        postable: true,
        system_account: false
      },
      {
        code: "6020",
        name: "Utilities Expense",
        parent_code: "6000",
        account_type: "expense",
        normal_balance: "debit",
        report_group: "operating_expense",
        postable: true,
        system_account: false
      },
      {
        code: "6030",
        name: "Bank Charges",
        parent_code: "6000",
        account_type: "expense",
        normal_balance: "debit",
        report_group: "operating_expense",
        postable: true,
        system_account: false
      },
      {
        code: "6040",
        name: "Salaries and Wages",
        parent_code: "6000",
        account_type: "expense",
        normal_balance: "debit",
        report_group: "operating_expense",
        postable: true,
        system_account: false
      },
      {
        code: "6050",
        name: "Transport Expense",
        parent_code: "6000",
        account_type: "expense",
        normal_balance: "debit",
        report_group: "operating_expense",
        postable: true,
        system_account: false
      },
      {
        code: "6090",
        name: "Miscellaneous Expense",
        parent_code: "6000",
        account_type: "expense",
        normal_balance: "debit",
        report_group: "operating_expense",
        postable: true,
        system_account: false
      }
    ].freeze

    MAPPINGS = {
      accounts_receivable: "1100",
      inventory: "1200",
      supplier_credit_receivable: "1300",
      input_tax: "1400",
      accounts_payable: "2010",
      customer_refund_payable: "2020",
      output_tax: "2100",
      opening_balance_equity: "3090",
      retained_earnings: "3100",
      sales_revenue: "4010",
      sales_returns: "4090",
      inventory_adjustment_gain: "4900",
      cost_of_goods_sold: "5010",
      inventory_adjustment_loss: "5090"
    }.freeze

    def initialize(organization:)
      @organization =
        organization
    end

    def call
      ApplicationRecord.transaction do
        organization.lock!

        accounts =
          provision_accounts

        provision_mappings(
          accounts
        )

        accounts
      end
    end

    private

    attr_reader :organization

    def provision_accounts
      accounts = {}

      ACCOUNTS.each do |definition|
        parent =
          if definition[:parent_code].present?
            accounts.fetch(
              definition[:parent_code]
            )
          end

        account =
          organization
            .ledger_accounts
            .find_or_initialize_by(
              code: definition.fetch(:code)
            )

        account.assign_attributes(
          name: definition.fetch(:name),
          parent: parent,
          account_type:
            definition.fetch(:account_type),
          normal_balance:
            definition.fetch(:normal_balance),
          report_group:
            definition.fetch(:report_group),
          postable:
            definition.fetch(:postable),
          active: true,
          system_account:
            definition.fetch(:system_account)
        )

        account.save!

        accounts[
          definition.fetch(:code)
        ] = account
      end

      accounts
    end

    def provision_mappings(accounts)
      MAPPINGS.each do |role, account_code|
        mapping =
          organization
            .accounting_account_mappings
            .find_or_initialize_by(
              role: role
            )

        mapping.ledger_account =
          accounts.fetch(
            account_code
          )

        mapping.save!
      end
    end
  end
end
