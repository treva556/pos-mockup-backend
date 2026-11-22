module Accounting
  module Reports
    class ProfitAndLoss
      Row =
        Struct.new(
          :ledger_account,
          :amount,
          keyword_init: true
        )

      Result =
        Struct.new(
          :from_date,
          :to_date,
          :branch,
          :revenue_rows,
          :cost_of_sales_rows,
          :operating_expense_rows,
          :other_income_rows,
          :other_expense_rows,
          :total_revenue,
          :total_cost_of_sales,
          :gross_profit,
          :total_operating_expenses,
          :operating_profit,
          :total_other_income,
          :total_other_expenses,
          :net_profit,
          keyword_init: true
        )

      def self.call(
        organization:,
        from_date:,
        to_date:,
        branch: nil
      )
        new(
          organization: organization,
          from_date: from_date,
          to_date: to_date,
          branch: branch
        ).call
      end

      def initialize(
        organization:,
        from_date:,
        to_date:,
        branch:
      )
        @organization =
          organization

        @from_date =
          normalize_date(
            from_date
          )

        @to_date =
          normalize_date(
            to_date
          )

        @branch =
          branch
      end

      def call
        validate_inputs!

        balances =
          account_balances

        revenue_rows =
          rows_for(
            balances,
            %w[
              revenue
              contra_revenue
            ]
          )

        cost_of_sales_rows =
          rows_for(
            balances,
            %w[
              cost_of_sales
            ]
          )

        operating_expense_rows =
          rows_for(
            balances,
            %w[
              operating_expense
            ]
          )

        other_income_rows =
          rows_for(
            balances,
            %w[
              other_income
            ]
          )

        other_expense_rows =
          rows_for(
            balances,
            %w[
              other_expense
            ]
          )

        total_revenue =
          money(
            revenue_rows.sum(
              &:amount
            )
          )

        total_cost_of_sales =
          money(
            cost_of_sales_rows.sum(
              &:amount
            )
          )

        gross_profit =
          money(
            total_revenue -
            total_cost_of_sales
          )

        total_operating_expenses =
          money(
            operating_expense_rows.sum(
              &:amount
            )
          )

        operating_profit =
          money(
            gross_profit -
            total_operating_expenses
          )

        total_other_income =
          money(
            other_income_rows.sum(
              &:amount
            )
          )

        total_other_expenses =
          money(
            other_expense_rows.sum(
              &:amount
            )
          )

        net_profit =
          money(
            operating_profit +
            total_other_income -
            total_other_expenses
          )

        Result.new(
          from_date:
            from_date,
          to_date:
            to_date,
          branch:
            branch,
          revenue_rows:
            revenue_rows,
          cost_of_sales_rows:
            cost_of_sales_rows,
          operating_expense_rows:
            operating_expense_rows,
          other_income_rows:
            other_income_rows,
          other_expense_rows:
            other_expense_rows,
          total_revenue:
            total_revenue,
          total_cost_of_sales:
            total_cost_of_sales,
          gross_profit:
            gross_profit,
          total_operating_expenses:
            total_operating_expenses,
          operating_profit:
            operating_profit,
          total_other_income:
            total_other_income,
          total_other_expenses:
            total_other_expenses,
          net_profit:
            net_profit
        )
      end

      private

      attr_reader :organization,
                  :from_date,
                  :to_date,
                  :branch

      def validate_inputs!
        if from_date > to_date
          raise ArgumentError,
                "From date cannot be after to date"
        end

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
              :journal_entry,
              :ledger_account
            )
            .where(
              journal_entries: {
                status:
                  %w[
                    posted
                    reversed
                  ],
                entry_date:
                  from_date..to_date
              }
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

        account_ids.to_h do |account_id|
          account =
            organization
              .ledger_accounts
              .find(
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

          amount =
            if account.normal_balance_credit?
              credit - debit
            else
              debit - credit
            end

          [
            account_id,
            money(
              amount
            )
          ]
        end
      end

      def rows_for(
        balances,
        report_groups
      )
        organization
          .ledger_accounts
          .postable
          .ordered
          .where(
            report_group:
              report_groups
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
                money(
                  amount
                )
            )
          end
      end

      def normalize_date(value)
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
