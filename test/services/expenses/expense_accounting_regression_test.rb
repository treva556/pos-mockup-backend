require "test_helper"

class Expenses::ExpenseAccountingRegressionTest <
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

    @rent =
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

    @cash =
      @organization
        .ledger_accounts
        .create!(
          code: "1011",
          name: "Regression Cash",
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
          name: "Regression Cash",
          account_type: "cash",
          branch: @branch,
          ledger_account: @cash,
          opening_balance: 10_000,
          opening_balance_date: Date.new(2026, 11, 1),
          can_receive: true,
          can_pay: true,
          active: true
        )
  end

  test "expense flows through money balance general ledger and trial balance" do
    expense =
      Expenses::CreateExpense.call(
        organization: @organization,
        recorded_by: @owner,
        expense_account: @rent,
        money_account: @money_account,
        expense_date: Date.new(2026, 11, 20),
        amount: 2_000,
        branch: @branch
      )

    assert_equal 8_000.to_d,
                 @money_account.reload.current_balance

    rent_ledger =
      Accounting::Reports::GeneralLedger.call(
        organization: @organization,
        ledger_account: @rent,
        to_date: Date.new(2026, 11, 30)
      )

    assert_equal 2_000.to_d,
                 rent_ledger.closing_balance

    trial_balance =
      Accounting::Reports::TrialBalance.call(
        organization: @organization,
        as_of_date: Date.new(2026, 11, 30)
      )

    assert trial_balance.balanced

    Expenses::ReverseExpense.call(
      expense: expense,
      reversed_by: @owner,
      reversal_date: Date.new(2026, 11, 21)
    )

    assert_equal 10_000.to_d,
                 @money_account.reload.current_balance

    rent_ledger =
      Accounting::Reports::GeneralLedger.call(
        organization: @organization,
        ledger_account: @rent,
        to_date: Date.new(2026, 11, 30)
      )

    assert_equal 0.to_d,
                 rent_ledger.closing_balance

    trial_balance =
      Accounting::Reports::TrialBalance.call(
        organization: @organization,
        as_of_date: Date.new(2026, 11, 30)
      )

    assert trial_balance.balanced
  end
end
