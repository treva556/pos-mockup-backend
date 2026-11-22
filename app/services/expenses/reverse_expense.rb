module Expenses
  class ReverseExpense
    class ReversalError < StandardError; end

    def self.call(
      expense:,
      reversed_by:,
      reversal_date: Date.current
    )
      new(
        expense: expense,
        reversed_by: reversed_by,
        reversal_date: reversal_date
      ).call
    end

    def initialize(
      expense:,
      reversed_by:,
      reversal_date:
    )
      @expense = expense
      @reversed_by = reversed_by
      @reversal_date = normalize_date(
        reversal_date
      )
    end

    def call
      Expense.transaction do
        expense.lock!

        validate!

        reverse_accounting!

        expense.update!(
          status: "reversed",
          reversed_at: Time.current,
          reversed_by: reversed_by
        )

        expense
      end
    end

    private

    attr_reader :expense,
                :reversed_by,
                :reversal_date

    def validate!
      if expense.status_reversed?
        raise ReversalError,
              "Expense has already been reversed"
      end

      unless expense.organization
        .memberships
        .active
        .exists?(
          user_id: reversed_by.id
        )
        raise ReversalError,
              "Reversing user must be an active organization member"
      end

      if reversal_date <
         expense.expense_date
        raise ReversalError,
              "Reversal date cannot be before expense date"
      end
    end

    def reverse_accounting!
      return unless expense.organization.accounting_enabled?

      journal =
        expense.organization
          .journal_entries
          .find_by!(
            source: expense
          )

      Accounting::ReverseJournalEntry.call(
        journal_entry: journal,
        reversed_by: reversed_by,
        reversal_date: reversal_date,
        description:
          "Reversal of expense: #{expense.expense_account.name}"
      )
    end

    def normalize_date(value)
      return value if value.is_a?(Date)

      Date.iso8601(
        value.to_s
      )
    rescue ArgumentError
      raise ReversalError,
            "Invalid reversal date"
    end
  end
end
