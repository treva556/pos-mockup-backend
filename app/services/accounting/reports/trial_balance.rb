module Accounting
  module Reports
    class TrialBalance
      Row =
        Struct.new(
          :ledger_account,
          :debit,
          :credit,
          keyword_init: true
        )

      Result =
        Struct.new(
          :as_of_date,
          :branch,
          :rows,
          :total_debits,
          :total_credits,
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
          )

        @branch =
          branch
      end

      def call
        validate_inputs!

        rows =
          build_rows

        total_debits =
          money(
            rows.sum(
              &:debit
            )
          )

        total_credits =
          money(
            rows.sum(
              &:credit
            )
          )

        Result.new(
          as_of_date:
            as_of_date,
          branch:
            branch,
          rows:
            rows,
          total_debits:
            total_debits,
          total_credits:
            total_credits,
          balanced:
            total_debits ==
              total_credits
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

      def build_rows
        balances =
          account_balances

        organization
          .ledger_accounts
          .postable
          .ordered
          .filter_map do |account|
            balance =
              balances.fetch(
                account.id,
                0.to_d
              )

            next if balance.zero?

            build_row(
              account,
              balance
            )
          end
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

        if as_of_date.present?
          scope =
            scope.where(
              "journal_entries.entry_date <= ?",
              as_of_date
            )
        end

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

          [
            account_id,
            money(
              debit - credit
            )
          ]
        end
      end

      def build_row(
        account,
        balance
      )
        if balance.positive?
          Row.new(
            ledger_account:
              account,
            debit:
              money(
                balance
              ),
            credit:
              0.to_d
          )
        else
          Row.new(
            ledger_account:
              account,
            debit:
              0.to_d,
            credit:
              money(
                balance.abs
              )
          )
        end
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
