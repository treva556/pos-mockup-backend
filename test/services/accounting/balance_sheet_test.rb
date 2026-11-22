require "test_helper"

class Accounting::BalanceSheetTest <
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

    @inventory =
      @organization
        .ledger_accounts
        .find_by!(
          code: "1200"
        )

    @payable =
      @organization
        .ledger_accounts
        .find_by!(
          code: "2010"
        )

    @capital =
      @organization
        .ledger_accounts
        .find_by!(
          code: "3010"
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

  test "balances assets against liabilities equity and current earnings" do
    create_capital_journal(
      date: Date.new(2026, 11, 1),
      amount: 10_000
    )

    create_sale_journal(
      date: Date.new(2026, 11, 10),
      amount: 4_000
    )

    create_expense_journal(
      date: Date.new(2026, 11, 15),
      amount: 1_000
    )

    result =
      Accounting::Reports::BalanceSheet.call(
        organization:
          @organization,
        as_of_date:
          Date.new(2026, 11, 30)
      )

    assert_equal 13_000.to_d,
                 result.total_assets

    assert_equal 0.to_d,
                 result.total_liabilities

    assert_equal 10_000.to_d,
                 result.account_equity

    assert_equal 3_000.to_d,
                 result.current_earnings

    assert_equal 13_000.to_d,
                 result.total_equity

    assert_equal 13_000.to_d,
                 result.total_liabilities_and_equity

    assert result.balanced
    assert_equal 0.to_d,
                 result.difference
  end

  test "includes liabilities in accounting equation" do
    create_capital_journal(
      date: Date.new(2026, 11, 1),
      amount: 10_000
    )

    Accounting::CreateJournalEntry.call(
      organization:
        @organization,
      created_by:
        @owner,
      entry_date:
        Date.new(2026, 11, 5),
      description:
        "Inventory on credit",
      lines: [
        {
          ledger_account:
            @inventory,
          branch:
            @branch,
          debit: 2_000,
          credit: 0
        },
        {
          ledger_account:
            @payable,
          branch:
            @branch,
          debit: 0,
          credit: 2_000
        }
      ]
    )

    result =
      Accounting::Reports::BalanceSheet.call(
        organization:
          @organization,
        as_of_date:
          Date.new(2026, 11, 30)
      )

    assert_equal 12_000.to_d,
                 result.total_assets

    assert_equal 2_000.to_d,
                 result.total_liabilities

    assert_equal 10_000.to_d,
                 result.total_equity

    assert result.balanced
  end

  test "respects as of date" do
    create_capital_journal(
      date: Date.new(2026, 11, 1),
      amount: 5_000
    )

    create_sale_journal(
      date: Date.new(2026, 12, 10),
      amount: 7_000
    )

    result =
      Accounting::Reports::BalanceSheet.call(
        organization:
          @organization,
        as_of_date:
          Date.new(2026, 11, 30)
      )

    assert_equal 5_000.to_d,
                 result.total_assets

    assert_equal 0.to_d,
                 result.current_earnings

    assert result.balanced
  end

  test "reversal neutralizes balance sheet activity" do
    create_capital_journal(
      date: Date.new(2026, 11, 1),
      amount: 10_000
    )

    journal =
      create_sale_journal(
        date: Date.new(2026, 11, 10),
        amount: 3_000
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
      Accounting::Reports::BalanceSheet.call(
        organization:
          @organization,
        as_of_date:
          Date.new(2026, 11, 30)
      )

    assert_equal 10_000.to_d,
                 result.total_assets

    assert_equal 0.to_d,
                 result.current_earnings

    assert_equal 10_000.to_d,
                 result.total_equity

    assert result.balanced
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

    create_capital_journal(
      date: Date.new(2026, 11, 1),
      amount: 2_000,
      branch: @branch
    )

    create_capital_journal(
      date: Date.new(2026, 11, 1),
      amount: 8_000,
      branch: second_branch
    )

    result =
      Accounting::Reports::BalanceSheet.call(
        organization:
          @organization,
        as_of_date:
          Date.new(2026, 11, 30),
        branch:
          second_branch
      )

    assert_equal 8_000.to_d,
                 result.total_assets

    assert_equal 8_000.to_d,
                 result.total_equity

    assert result.balanced
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
      Accounting::Reports::BalanceSheet.call(
        organization:
          @organization,
        as_of_date:
          Date.new(2026, 11, 30),
        branch:
          other_organization.main_branch
      )
    end
  end

  private

  def create_capital_journal(
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
        "Balance sheet capital test",
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
            @capital,
          branch:
            branch,
          debit: 0,
          credit:
            amount
        }
      ]
    )
  end

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
        "Balance sheet revenue test",
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
            @revenue,
          branch:
            branch,
          debit: 0,
          credit:
            amount
        }
      ]
    )
  end

  def create_expense_journal(
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
        "Balance sheet expense test",
      lines: [
        {
          ledger_account:
            @rent,
          branch:
            branch,
          debit:
            amount,
          credit: 0
        },
        {
          ledger_account:
            @receivable,
          branch:
            branch,
          debit: 0,
          credit:
            amount
        }
      ]
    )
  end
end
