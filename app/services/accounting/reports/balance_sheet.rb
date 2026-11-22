module Accounting
  module Reports
    class BalanceSheet
      Row =
        Struct.new(
          :ledger_account,
          :amount,
          keyword_init: true
        )

      Result =
        Struct.new(
          :as_of_date,
          :branch,
          :current_asset_rows,
          :non_current_asset_rows,
          :contra_asset_rows,
          :current_liability_rows,
          :non_current_liability_rows,
          :equity_rows,
          :total_current_assets,
          :total_non_current_assets,
          :total_contra_assets,
          :total_assets,
          :total_current_liabilities,
          :total_non_current_liabilities,
          :total_liabilities,
          :account_equity,
          :current_earnings,
          :total_equity,
          :total_liabilities_and_equity,
          :difference,
          :balanced,
          keyword_init: true
        )

      def self.call(
        organization:,
        as_of_date: nil,
        branch: nil
      )
        new(
          organization: organization,
          as_of_date: as_of_date,
          branch: branch
        ).call
      end

      def initialize(
        organization:,
        as_of_date:,
        branch:
      )
        @organization =
          organization

        @as_of_date =
          normalize_date(
            as_of_date
          ) ||
          Date.current

        @branch =
          branch
      end

      def call
        validate_inputs!

        balances =
          account_balances

        current_asset_rows =
          rows_for(
            balances,
            "current_asset"
          )

        non_current_asset_rows =
          rows_for(
            balances,
            "non_current_asset"
          )

        contra_asset_rows =
          rows_for(
            balances,
            "contra_asset"
          )

        current_liability_rows =
          rows_for(
            balances,
            "current_liability"
          )

        non_current_liability_rows =
          rows_for(
            balances,
            "non_current_liability"
          )

        equity_rows =
          rows_for(
            balances,
            "equity"
          )

        total_current_assets =
          row_total(
            current_asset_rows
          )

        total_non_current_assets =
          row_total(
            non_current_asset_rows
          )

        total_contra_assets =
          row_total(
            contra_asset_rows
          )

        total_assets =
          money(
            total_current_assets +
            total_non_current_assets -
            total_contra_assets
          )

        total_current_liabilities =
          row_total(
            current_liability_rows
          )

        total_non_current_liabilities =
          row_total(
            non_current_liability_rows
          )

        total_liabilities =
          money(
            total_current_liabilities +
            total_non_current_liabilities
          )

        account_equity =
          row_total(
            equity_rows
          )

        current_earnings =
          calculate_current_earnings(
            balances
          )

        total_equity =
          money(
            account_equity +
            current_earnings
          )

        total_liabilities_and_equity =
          money(
            total_liabilities +
            total_equity
          )

        difference =
          money(
            total_assets -
            total_liabilities_and_equity
          )

        Result.new(
          as_of_date:
            as_of_date,
          branch:
            branch,
          current_asset_rows:
            current_asset_rows,
          non_current_asset_rows:
            non_current_asset_rows,
          contra_asset_rows:
            contra_asset_rows,
          current_liability_rows:
            current_liability_rows,
          non_current_liability_rows:
            non_current_liability_rows,
          equity_rows:
            equity_rows,
          total_current_assets:
            total_current_assets,
          total_non_current_assets:
            total_non_current_assets,
          total_contra_assets:
            total_contra_assets,
          total_assets:
            total_assets,
          total_current_liabilities:
            total_current_liabilities,
          total_non_current_liabilities:
            total_non_current_liabilities,
          total_liabilities:
            total_liabilities,
          account_equity:
            account_equity,
          current_earnings:
            current_earnings,
          total_equity:
            total_equity,
          total_liabilities_and_equity:
            total_liabilities_and_equity,
          difference:
            difference,
          balanced:
            difference.zero?
        )
      end

      private

      attr_reader :organization,
                  :as_of_date,
                  :branch

      def validate_inputs!
        return if branch.blank?

        return if branch.organization_id ==
                  organization.id

        raise ArgumentError,
              "Branch must belong to the organization"
      end

      def account_balances
        scope =
          organization
            .journal_lines
            .joins(
              :journal_entry
            )
            .where(
              journal_entries: {
                status:
                  %w[
                    posted
                    reversed
                  ]
              }
            )
            .where(
              "journal_entries.entry_date <= ?",
              as_of_date
            )

        if branch.present?
          scope =
            scope.where(
              branch_id:
                branch.id
            )
        end

        debit_totals =
          scope
            .group(
              :ledger_account_id
            )
            .sum(
              :debit
            )

        credit_totals =
          scope
            .group(
              :ledger_account_id
            )
            .sum(
              :credit
            )

        account_ids =
          debit_totals.keys |
          credit_totals.keys

        accounts =
          organization
            .ledger_accounts
            .where(
              id: account_ids
            )
            .index_by(&:id)

        account_ids.to_h do |account_id|
          account =
            accounts.fetch(
              account_id
            )

          debit =
            debit_totals
              .fetch(
                account_id,
                0
              )
              .to_d

          credit =
            credit_totals
              .fetch(
                account_id,
                0
              )
              .to_d

          balance =
            if account.normal_balance_credit?
              credit - debit
            else
              debit - credit
            end

          [
            account_id,
            money(
              balance
            )
          ]
        end
      end

      def rows_for(
        balances,
        report_group
      )
        organization
          .ledger_accounts
          .postable
          .ordered
          .where(
            report_group:
              report_group
          )
          .filter_map do |account|
            amount =
              balances.fetch(
                account.id,
                0.to_d
              )

            next if amount.zero?

            Row.new(
              ledger_account:
                account,
              amount:
                amount
            )
          end
      end

      def calculate_current_earnings(
        balances
      )
        revenue =
          group_total(
            balances,
            "revenue"
          )

        contra_revenue =
          group_total(
            balances,
            "contra_revenue"
          )

        cost_of_sales =
          group_total(
            balances,
            "cost_of_sales"
          )

        operating_expenses =
          group_total(
            balances,
            "operating_expense"
          )

        other_income =
          group_total(
            balances,
            "other_income"
          )

        other_expenses =
          group_total(
            balances,
            "other_expense"
          )

        money(
          revenue -
          contra_revenue -
          cost_of_sales -
          operating_expenses +
          other_income -
          other_expenses
        )
      end

      def group_total(
        balances,
        report_group
      )
        account_ids =
          organization
            .ledger_accounts
            .postable
            .where(
              report_group:
                report_group
            )
            .pluck(
              :id
            )

        money(
          account_ids.sum {
            |account_id|
            balances.fetch(
              account_id,
              0.to_d
            )
          }
        )
      end

      def row_total(rows)
        money(
          rows.sum(
            &:amount
          )
        )
      end

      def normalize_date(value)
        return if value.blank?

        return value if value.is_a?(
          Date
        )

        Date.iso8601(
          value.to_s
        )
      rescue ArgumentError
        raise ArgumentError,
              "Invalid report date"
      end

      def money(value)
        value.to_d.round(2)
      end
    end
  end
end
