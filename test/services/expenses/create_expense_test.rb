require "test_helper"

class Expenses::CreateExpenseTest <
  ActiveSupport::TestCase
  setup do
    @owner =
      create_user

    @organization =
      provision_organization_for(
        @owner
      )

    @organization.update!(
      accounting_enabled: true
    )

    @branch =
      @organization.main_branch

    @expense_account =
      @organization
        .ledger_accounts
        .find_by!(
          code: "6010"
        )

    cash_heading =
      @organization
        .ledger_accounts
        .find_by!(
          code: "1010"
        )

    @cash_ledger =
      @organization
        .ledger_accounts
        .create!(
          code: "1011",
          name: "Test Cash",
          parent: cash_heading,
          account_type: "asset",
          normal_balance: "debit",
          report_group: "current_asset",
          postable: true,
          system_account: false,
          active: true
        )

    @money_account =
      @organization
        .money_accounts
        .create!(
          name: "Main Cash",
          account_type: "cash",
          branch: @branch,
          ledger_account: @cash_ledger,
          opening_balance: 5_000,
          opening_balance_date: Date.new(2026, 11, 1),
          can_receive: true,
          can_pay: true,
          active: true
        )
  end

  test "creates expense and posts accounting journal" do
    expense =
      Expenses::CreateExpense.call(
        organization: @organization,
        recorded_by: @owner,
        expense_account: @expense_account,
        money_account: @money_account,
        expense_date: Date.new(2026, 11, 20),
        amount: 1_200,
        branch: @branch,
        payee: "Landlord",
        reference: "RENT-NOV",
        notes: "November rent"
      )

    assert expense.persisted?

    journal =
      @organization
        .journal_entries
        .find_by!(
          source: expense
        )

    assert journal.status_posted?

    assert_equal 1_200.to_d,
                 journal.total_debits

    assert_equal 1_200.to_d,
                 journal.total_credits
  end

  test "expense reduces money account current balance" do
    assert_equal 5_000.to_d,
                 @money_account.current_balance

    Expenses::CreateExpense.call(
      organization: @organization,
      recorded_by: @owner,
      expense_account: @expense_account,
      money_account: @money_account,
      expense_date: Date.new(2026, 11, 20),
      amount: 750,
      branch: @branch
    )

    assert_equal 4_250.to_d,
                 @money_account.reload.current_balance
  end

  test "rejects expense greater than available money account balance" do
    assert_no_difference(
      -> { Expense.count }
    ) do
      assert_raises(
        Expenses::CreateExpense::ExpenseError
      ) do
        Expenses::CreateExpense.call(
          organization: @organization,
          recorded_by: @owner,
          expense_account: @expense_account,
          money_account: @money_account,
          expense_date: Date.new(2026, 11, 20),
          amount: 6_000,
          branch: @branch
        )
      end
    end
  end

  test "rejects money account without ledger mapping" do
    unmapped_account =
      @organization
        .money_accounts
        .create!(
          name: "Unmapped Cash",
          account_type: "cash",
          branch: @branch,
          opening_balance: 2_000,
          opening_balance_date: Date.new(2026, 11, 1),
          can_receive: true,
          can_pay: true,
          active: true
        )

    assert_raises(
      Expenses::CreateExpense::ExpenseError
    ) do
      Expenses::CreateExpense.call(
        organization: @organization,
        recorded_by: @owner,
        expense_account: @expense_account,
        money_account: unmapped_account,
        expense_date: Date.new(2026, 11, 20),
        amount: 500,
        branch: @branch
      )
    end
  end

  test "closed accounting period rolls back expense completely" do
    @organization
      .accounting_periods
      .create!(
        name: "November 2026",
        starts_on: Date.new(2026, 11, 1),
        ends_on: Date.new(2026, 11, 30),
        status: "closed",
        closed_at: Time.current,
        closed_by: @owner
      )

    assert_no_difference(
      -> { Expense.count }
    ) do
      assert_raises(
        Accounting::PostJournalEntry::PostingError
      ) do
        Expenses::CreateExpense.call(
          organization: @organization,
          recorded_by: @owner,
          expense_account: @expense_account,
          money_account: @money_account,
          expense_date: Date.new(2026, 11, 20),
          amount: 500,
          branch: @branch
        )
      end
    end
  end
end
