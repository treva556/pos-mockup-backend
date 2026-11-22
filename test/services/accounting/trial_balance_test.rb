require "test_helper"

class Accounting::TrialBalanceTest <
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
  end

  test "produces balanced trial balance" do
    create_journal(
      entry_date:
        Date.new(2026, 11, 10),
      amount:
        500
    )

    result =
      Accounting::Reports::TrialBalance.call(
        organization:
          @organization,
        as_of_date:
          Date.new(2026, 11, 30)
      )

    assert result.balanced

    assert_equal 500.to_d,
                 result.total_debits

    assert_equal 500.to_d,
                 result.total_credits

    receivable_row =
      result.rows.find {
        |row|
        row.ledger_account ==
          @receivable
      }

    revenue_row =
      result.rows.find {
        |row|
        row.ledger_account ==
          @revenue
      }

    assert_equal 500.to_d,
                 receivable_row.debit

    assert_equal 0.to_d,
                 receivable_row.credit

    assert_equal 0.to_d,
                 revenue_row.debit

    assert_equal 500.to_d,
                 revenue_row.credit
  end

  test "respects as of date" do
    create_journal(
      entry_date:
        Date.new(2026, 11, 10),
      amount:
        300
    )

    create_journal(
      entry_date:
        Date.new(2026, 12, 10),
      amount:
        700
    )

    result =
      Accounting::Reports::TrialBalance.call(
        organization:
          @organization,
        as_of_date:
          Date.new(2026, 11, 30)
      )

    assert_equal 300.to_d,
                 result.total_debits

    assert_equal 300.to_d,
                 result.total_credits
  end

  test "reversal removes original balance" do
    journal =
      create_journal(
        entry_date:
          Date.new(2026, 11, 10),
        amount:
          400
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
      Accounting::Reports::TrialBalance.call(
        organization:
          @organization,
        as_of_date:
          Date.new(2026, 11, 30)
      )

    assert result.balanced

    assert_equal 0.to_d,
                 result.total_debits

    assert_equal 0.to_d,
                 result.total_credits

    assert_empty result.rows
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

    create_journal(
      entry_date:
        Date.new(2026, 11, 10),
      amount:
        100,
      branch:
        @branch
    )

    create_journal(
      entry_date:
        Date.new(2026, 11, 11),
      amount:
        250,
      branch:
        second_branch
    )

    result =
      Accounting::Reports::TrialBalance.call(
        organization:
          @organization,
        as_of_date:
          Date.new(2026, 11, 30),
        branch:
          second_branch
      )

    assert result.balanced

    assert_equal 250.to_d,
                 result.total_debits

    assert_equal 250.to_d,
                 result.total_credits
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
      Accounting::Reports::TrialBalance.call(
        organization:
          @organization,
        branch:
          other_organization.main_branch
      )
    end
  end

  private

  def create_journal(
    entry_date:,
    amount:,
    branch: @branch
  )
    Accounting::CreateJournalEntry.call(
      organization:
        @organization,
      created_by:
        @owner,
      entry_date:
        entry_date,
      description:
        "Trial balance test",
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
end
