require "test_helper"

class Accounting::ProfitAndLossTest <
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

    @sales_revenue =
      @organization
        .ledger_accounts
        .find_by!(
          code: "4010"
        )

    @inventory =
      @organization
        .ledger_accounts
        .find_by!(
          code: "1200"
        )

    @cost_of_sales =
      @organization
        .ledger_accounts
        .find_by!(
          code: "5010"
        )

    @rent =
      @organization
        .ledger_accounts
        .find_by!(
          code: "6010"
        )
  end

  test "calculates revenue gross profit operating profit and net profit" do
    create_sale_journal(
      date: Date.new(2026, 11, 10),
      amount: 10_000
    )

    create_cost_of_sales_journal(
      date: Date.new(2026, 11, 10),
      amount: 4_000
    )

    create_expense_journal(
      date: Date.new(2026, 11, 15),
      amount: 1_500
    )

    result =
      Accounting::Reports::ProfitAndLoss.call(
        organization:
          @organization,
        from_date:
          Date.new(2026, 11, 1),
        to_date:
          Date.new(2026, 11, 30)
      )

    assert_equal 10_000.to_d,
                 result.total_revenue

    assert_equal 4_000.to_d,
                 result.total_cost_of_sales

    assert_equal 6_000.to_d,
                 result.gross_profit

    assert_equal 1_500.to_d,
                 result.total_operating_expenses

    assert_equal 4_500.to_d,
                 result.operating_profit

    assert_equal 4_500.to_d,
                 result.net_profit
  end

  test "respects report date range" do
    create_sale_journal(
      date: Date.new(2026, 10, 20),
      amount: 7_000
    )

    create_sale_journal(
      date: Date.new(2026, 11, 10),
      amount: 3_000
    )

    result =
      Accounting::Reports::ProfitAndLoss.call(
        organization:
          @organization,
        from_date:
          Date.new(2026, 11, 1),
        to_date:
          Date.new(2026, 11, 30)
      )

    assert_equal 3_000.to_d,
                 result.total_revenue
  end

  test "reversal neutralizes profit and loss activity" do
    journal =
      create_sale_journal(
        date: Date.new(2026, 11, 10),
        amount: 5_000
      )

    Accounting::ReverseJournalEntry.call(
      journal_entry:
        journal,
      reversed_by:
        @owner,
      reversal_date:
        Date.new(2026, 11, 11)
    )

    result =
      Accounting::Reports::ProfitAndLoss.call(
        organization:
          @organization,
        from_date:
          Date.new(2026, 11, 1),
        to_date:
          Date.new(2026, 11, 30)
      )

    assert_equal 0.to_d,
                 result.total_revenue

    assert_equal 0.to_d,
                 result.net_profit
  end

  test "filters by branch" do
    second_branch =
      @organization
        .branches
        .create!(
          name: "Second Branch",
          code: "SECOND",
          main: false,
          active: true
        )

    create_sale_journal(
      date: Date.new(2026, 11, 10),
      amount: 2_000,
      branch: @branch
    )

    create_sale_journal(
      date: Date.new(2026, 11, 11),
      amount: 8_000,
      branch: second_branch
    )

    result =
      Accounting::Reports::ProfitAndLoss.call(
        organization:
          @organization,
        from_date:
          Date.new(2026, 11, 1),
        to_date:
          Date.new(2026, 11, 30),
        branch:
          second_branch
      )

    assert_equal 8_000.to_d,
                 result.total_revenue
  end

  test "rejects invalid date range" do
    assert_raises(
      ArgumentError
    ) do
      Accounting::Reports::ProfitAndLoss.call(
        organization:
          @organization,
        from_date:
          Date.new(2026, 12, 1),
        to_date:
          Date.new(2026, 11, 1)
      )
    end
  end

  test "rejects branch from another organization" do
    other_owner =
      create_user

    other_organization =
      provision_organization_for(
        other_owner
      )

    assert_raises(
      ArgumentError
    ) do
      Accounting::Reports::ProfitAndLoss.call(
        organization:
          @organization,
        from_date:
          Date.new(2026, 11, 1),
        to_date:
          Date.new(2026, 11, 30),
        branch:
          other_organization.main_branch
      )
    end
  end

  private

  def create_sale_journal(
    date:,
    amount:,
    branch: @branch
  )
    Accounting::CreateJournalEntry.call(
      organization:
        @organization,
      created_by:
        @owner,
      entry_date:
        date,
      description:
        "P&L sales test",
      lines: [
        {
          ledger_account:
            @receivable,
          branch:
            branch,
          debit:
            amount,
          credit: 0
        },
        {
          ledger_account:
            @sales_revenue,
          branch:
            branch,
          debit: 0,
          credit:
            amount
        }
      ]
    )
  end

  def create_cost_of_sales_journal(
    date:,
    amount:
  )
    Accounting::CreateJournalEntry.call(
      organization:
        @organization,
      created_by:
        @owner,
      entry_date:
        date,
      description:
        "P&L cost of sales test",
      lines: [
        {
          ledger_account:
            @cost_of_sales,
          branch:
            @branch,
          debit:
            amount,
          credit: 0
        },
        {
          ledger_account:
            @inventory,
          branch:
            @branch,
          debit: 0,
          credit:
            amount
        }
      ]
    )
  end

  def create_expense_journal(
    date:,
    amount:
  )
    Accounting::CreateJournalEntry.call(
      organization:
        @organization,
      created_by:
        @owner,
      entry_date:
        date,
      description:
        "P&L expense test",
      lines: [
        {
          ledger_account:
            @rent,
          branch:
            @branch,
          debit:
            amount,
          credit: 0
        },
        {
          ledger_account:
            @receivable,
          branch:
            @branch,
          debit: 0,
          credit:
            amount
        }
      ]
    )
  end
end
