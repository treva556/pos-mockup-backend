module Expenses
  class CreateExpense
    class ExpenseError < StandardError; end

    def self.call(
      organization:,
      recorded_by:,
      expense_account:,
      money_account:,
      expense_date:,
      amount:,
      branch: nil,
      payee: nil,
      reference: nil,
      notes: nil
    )
      new(
        organization: organization,
        recorded_by: recorded_by,
        expense_account: expense_account,
        money_account: money_account,
        expense_date: expense_date,
        amount: amount,
        branch: branch,
        payee: payee,
        reference: reference,
        notes: notes
      ).call
    end

    def initialize(
      organization:,
      recorded_by:,
      expense_account:,
      money_account:,
      expense_date:,
      amount:,
      branch:,
      payee:,
      reference:,
      notes:
    )
      @organization =
        organization

      @recorded_by =
        recorded_by

      @expense_account =
        expense_account

      @money_account =
        money_account

      @expense_date =
        expense_date

      @amount =
        amount.to_d

      @branch =
        branch

      @payee =
        payee

      @reference =
        reference

      @notes =
        notes
    end

    def call
      Expense.transaction do
        money_account.lock!

        validate_money_account!

        expense =
          create_expense!

        post_accounting!(
          expense
        )

        expense
      end
    end

    private

    attr_reader :organization,
                :recorded_by,
                :expense_account,
                :money_account,
                :expense_date,
                :amount,
                :branch,
                :payee,
                :reference,
                :notes

    def validate_money_account!
      if money_account.ledger_account.blank?
        raise ExpenseError,
              "Money account must be linked to a ledger account"
      end

      if amount > money_account.current_balance
        raise ExpenseError,
              "Money account does not have enough balance"
      end
    end

    def create_expense!
      organization
        .expenses
        .create!(
          branch:
            branch ||
            money_account.branch,
          expense_account:
            expense_account,
          money_account:
            money_account,
          recorded_by:
            recorded_by,
          expense_date:
            expense_date,
          amount:
            amount,
          payee:
            payee,
          reference:
            reference,
          notes:
            notes
        )
    end

    def post_accounting!(expense)
      return unless organization.accounting_enabled?

      Accounting::CreateJournalEntry.call(
        organization:
          organization,
        created_by:
          recorded_by,
        entry_date:
          expense.expense_date,
        description:
          journal_description(
            expense
          ),
        source:
          expense,
        lines: [
          {
            ledger_account:
              expense.expense_account,
            branch:
              expense.branch,
            debit:
              expense.amount,
            credit: 0
          },
          {
            ledger_account:
              money_account.ledger_account,
            branch:
              money_account.branch,
            debit: 0,
            credit:
              expense.amount
          }
        ]
      )
    end

    def journal_description(expense)
      description =
        "Expense: #{expense.expense_account.name}"

      if expense.payee.present?
        description +=
          " - #{expense.payee}"
      end

      description
    end
  end
end
