require "test_helper"

class Expenses::ReverseExpenseTest <
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

    @expense =
      Expenses::CreateExpense.call(
        organization: @organization,
        recorded_by: @owner,
        expense_account: @expense_account,
        money_account: @money_account,
        expense_date: Date.new(2026, 11, 20),
        amount: 1_000,
        branch: @branch,
        payee: "Landlord"
      )
  end

  test "reverses expense and accounting journal" do
    result =
      Expenses::ReverseExpense.call(
        expense: @expense,
        reversed_by: @owner,
        reversal_date: Date.new(2026, 11, 21)
      )

    assert result.status_reversed?
    assert result.reversed_at.present?
    assert_equal @owner,
                 result.reversed_by

    original_journal =
      @organization
        .journal_entries
        .find_by!(
          source: @expense
        )

    assert original_journal.status_reversed?
    assert original_journal.reversal_entry.present?
    assert original_journal.reversal_entry.status_posted?
  end

  test "reversal restores money account balance" do
    assert_equal 4_000.to_d,
                 @money_account.reload.current_balance

    Expenses::ReverseExpense.call(
      expense: @expense,
      reversed_by: @owner,
      reversal_date: Date.new(2026, 11, 21)
    )

    assert_equal 5_000.to_d,
                 @money_account.reload.current_balance
  end

  test "cannot reverse expense twice" do
    Expenses::ReverseExpense.call(
      expense: @expense,
      reversed_by: @owner,
      reversal_date: Date.new(2026, 11, 21)
    )

    assert_raises(
      Expenses::ReverseExpense::ReversalError
    ) do
      Expenses::ReverseExpense.call(
        expense: @expense.reload,
        reversed_by: @owner,
        reversal_date: Date.new(2026, 11, 22)
      )
    end
  end

  test "cannot reverse before expense date" do
    assert_raises(
      Expenses::ReverseExpense::ReversalError
    ) do
      Expenses::ReverseExpense.call(
        expense: @expense,
        reversed_by: @owner,
        reversal_date: Date.new(2026, 11, 19)
      )
    end
  end

  test "closed reversal period rolls back expense reversal" do
    @organization
      .accounting_periods
      .create!(
        name: "December 2026",
        starts_on: Date.new(2026, 12, 1),
        ends_on: Date.new(2026, 12, 31),
        status: "closed",
        closed_at: Time.current,
        closed_by: @owner
      )

    assert_raises(
      Accounting::ReverseJournalEntry::ReversalError
    ) do
      Expenses::ReverseExpense.call(
        expense: @expense,
        reversed_by: @owner,
        reversal_date: Date.new(2026, 12, 5)
      )
    end

    assert @expense.reload.status_posted?

    assert_equal 4_000.to_d,
                 @money_account.reload.current_balance
  end
end
