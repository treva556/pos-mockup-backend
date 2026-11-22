require "test_helper"

class Accounting::FinancialReportsRegressionTest <
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

    @receivable =
      @organization
        .ledger_accounts
        .find_by!(
          code: "1100"
        )

    @revenue =
      @organization
        .ledger_accounts
        .find_by!(
          code: "4010"
        )

    @rent =
      @organization
        .ledger_accounts
        .find_by!(
          code: "6010"
        )
  end

  test "profit and loss net profit agrees with balance sheet current earnings" do
    create_revenue(
      Date.new(2026, 11, 10),
      5_000
    )

    create_expense(
      Date.new(2026, 11, 15),
      1_500
    )

    profit_and_loss =
      Accounting::Reports::ProfitAndLoss.call(
        organization: @organization,
        from_date: Date.new(2026, 1, 1),
        to_date: Date.new(2026, 11, 30)
      )

    balance_sheet =
      Accounting::Reports::BalanceSheet.call(
        organization: @organization,
        as_of_date: Date.new(2026, 11, 30)
      )

    assert_equal 3_500.to_d,
                 profit_and_loss.net_profit

    assert_equal profit_and_loss.net_profit,
                 balance_sheet.current_earnings
  end

  test "reversal updates profit and loss and balance sheet consistently" do
    journal =
      create_revenue(
        Date.new(2026, 11, 10),
        4_000
      )

    Accounting::ReverseJournalEntry.call(
      journal_entry: journal,
      reversed_by: @owner,
      reversal_date: Date.new(2026, 11, 11)
    )

    profit_and_loss =
      Accounting::Reports::ProfitAndLoss.call(
        organization: @organization,
        from_date: Date.new(2026, 11, 1),
        to_date: Date.new(2026, 11, 30)
      )

    balance_sheet =
      Accounting::Reports::BalanceSheet.call(
        organization: @organization,
        as_of_date: Date.new(2026, 11, 30)
      )

    assert_equal 0.to_d,
                 profit_and_loss.net_profit

    assert_equal 0.to_d,
                 balance_sheet.current_earnings
  end

  test "trial balance remains balanced with financial reports data" do
    create_revenue(
      Date.new(2026, 11, 10),
      5_000
    )

    create_expense(
      Date.new(2026, 11, 15),
      1_000
    )

    trial_balance =
      Accounting::Reports::TrialBalance.call(
        organization: @organization,
        as_of_date: Date.new(2026, 11, 30)
      )

    assert trial_balance.balanced

    assert_equal trial_balance.total_debits,
                 trial_balance.total_credits
  end

  test "branch filtered reports remain consistent" do
    second_branch =
      @organization
        .branches
        .create!(
          name: "Second Branch",
          code: "SECOND",
          main: false,
          active: true
        )

    create_revenue(
      Date.new(2026, 11, 10),
      2_000,
      branch: @branch
    )

    create_revenue(
      Date.new(2026, 11, 10),
      7_000,
      branch: second_branch
    )

    profit_and_loss =
      Accounting::Reports::ProfitAndLoss.call(
        organization: @organization,
        from_date: Date.new(2026, 11, 1),
        to_date: Date.new(2026, 11, 30),
        branch: second_branch
      )

    balance_sheet =
      Accounting::Reports::BalanceSheet.call(
        organization: @organization,
        as_of_date: Date.new(2026, 11, 30),
        branch: second_branch
      )

    assert_equal 7_000.to_d,
                 profit_and_loss.net_profit

    assert_equal 7_000.to_d,
                 balance_sheet.current_earnings
  end

  private

  def create_revenue(
    date,
    amount,
    branch: @branch
  )
    Accounting::CreateJournalEntry.call(
      organization: @organization,
      created_by: @owner,
      entry_date: date,
      description: "Financial reports regression revenue",
      lines: [
        {
          ledger_account: @receivable,
          branch: branch,
          debit: amount,
          credit: 0
        },
        {
          ledger_account: @revenue,
          branch: branch,
          debit: 0,
          credit: amount
        }
      ]
    )
  end

  def create_expense(
    date,
    amount,
    branch: @branch
  )
    Accounting::CreateJournalEntry.call(
      organization: @organization,
      created_by: @owner,
      entry_date: date,
      description: "Financial reports regression expense",
      lines: [
        {
          ledger_account: @rent,
          branch: branch,
          debit: amount,
          credit: 0
        },
        {
          ledger_account: @receivable,
          branch: branch,
          debit: 0,
          credit: amount
        }
      ]
    )
  end
end
