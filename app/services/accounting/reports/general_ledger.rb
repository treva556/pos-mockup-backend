module Accounting
  module Reports
    class GeneralLedger
      Line =
        Struct.new(
          :journal_line,
          :journal_entry,
          :entry_date,
          :entry_number,
          :description,
          :branch,
          :debit,
          :credit,
          :running_balance,
          keyword_init: true
        )

      Result =
        Struct.new(
          :ledger_account,
          :from_date,
          :to_date,
          :branch,
          :opening_balance,
          :total_debits,
          :total_credits,
          :net_movement,
          :closing_balance,
          :lines,
          keyword_init: true
        )

      def self.call(
        organization:,
        ledger_account:,
        from_date: nil,
        to_date: nil,
        branch: nil
      )
        new(
          organization: organization,
          ledger_account: ledger_account,
          from_date: from_date,
          to_date: to_date,
          branch: branch
        ).call
      end

      def initialize(
        organization:,
        ledger_account:,
        from_date:,
        to_date:,
        branch:
      )
        @organization =
          organization

        @ledger_account =
          ledger_account

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

        opening_balance =
          calculate_balance(
            opening_scope
          )

        running_balance =
          opening_balance

        report_lines =
          movement_scope.map do |journal_line|
            movement =
              signed_movement(
                debit:
                  journal_line.debit,
                credit:
                  journal_line.credit
              )

            running_balance +=
              movement

            build_line(
              journal_line,
              running_balance
            )
          end

        total_debits =
          money(
            report_lines.sum(
              &:debit
            )
          )

        total_credits =
          money(
            report_lines.sum(
              &:credit
            )
          )

        net_movement =
          money(
            signed_movement(
              debit:
                total_debits,
              credit:
                total_credits
            )
          )

        Result.new(
          ledger_account:
            ledger_account,
          from_date:
            from_date,
          to_date:
            to_date,
          branch:
            branch,
          opening_balance:
            money(
              opening_balance
            ),
          total_debits:
            total_debits,
          total_credits:
            total_credits,
          net_movement:
            net_movement,
          closing_balance:
            money(
              running_balance
            ),
          lines:
            report_lines
        )
      end

      private

      attr_reader :organization,
                  :ledger_account,
                  :from_date,
                  :to_date,
                  :branch

      def validate_inputs!
        unless ledger_account.organization_id ==
               organization.id
          raise ArgumentError,
                "Ledger account must belong to the organization"
        end

        if branch.present? &&
           branch.organization_id !=
             organization.id
          raise ArgumentError,
                "Branch must belong to the organization"
        end

        return unless from_date.present? &&
                      to_date.present? &&
                      from_date > to_date

        raise ArgumentError,
              "From date cannot be after to date"
      end

      def base_scope
        scope =
          organization
            .journal_lines
            .joins(
              :journal_entry
            )
            .includes(
              :branch,
              :journal_entry
            )
            .where(
              ledger_account_id:
                ledger_account.id
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

        if branch.present?
          scope =
            scope.where(
              branch_id:
                branch.id
            )
        end

        scope
      end

      def opening_scope
        return empty_scope if from_date.blank?

        base_scope.where(
          "journal_entries.entry_date < ?",
          from_date
        )
      end

      def movement_scope
        scope =
          base_scope

        if from_date.present?
          scope =
            scope.where(
              "journal_entries.entry_date >= ?",
              from_date
            )
        end

        if to_date.present?
          scope =
            scope.where(
              "journal_entries.entry_date <= ?",
              to_date
            )
        end

        scope.order(
          "journal_entries.entry_date ASC",
          "journal_entries.sequence_number ASC",
          "journal_lines.line_number ASC"
        )
      end

      def calculate_balance(scope)
        debit_total =
          scope.sum(
            :debit
          ).to_d

        credit_total =
          scope.sum(
            :credit
          ).to_d

        money(
          signed_movement(
            debit:
              debit_total,
            credit:
              credit_total
          )
        )
      end

      def signed_movement(
        debit:,
        credit:
      )
        debit =
          debit.to_d

        credit =
          credit.to_d

        if ledger_account.normal_balance_debit?
          debit - credit
        else
          credit - debit
        end
      end

      def build_line(
        journal_line,
        running_balance
      )
        journal_entry =
          journal_line.journal_entry

        Line.new(
          journal_line:
            journal_line,
          journal_entry:
            journal_entry,
          entry_date:
            journal_entry.entry_date,
          entry_number:
            journal_entry.entry_number,
          description:
            journal_line
              .description
              .presence ||
              journal_entry
                .description
                .presence,
          branch:
            journal_line.branch,
          debit:
            money(
              journal_line.debit
            ),
          credit:
            money(
              journal_line.credit
            ),
          running_balance:
            money(
              running_balance
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

      def empty_scope
        organization
          .journal_lines
          .none
      end

      def money(value)
        value.to_d.round(2)
      end
    end
  end
end
