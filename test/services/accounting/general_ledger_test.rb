require "test_helper"

class Accounting::GeneralLedgerTest <
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

  test "calculates opening movement and closing balance" do
    create_journal(
      entry_date:
        Date.new(2026, 11, 1),
      amount:
        100
    )

    create_journal(
      entry_date:
        Date.new(2026, 11, 10),
      amount:
        250
    )

    result =
      Accounting::Reports::GeneralLedger.call(
        organization:
          @organization,
        ledger_account:
          @receivable,
        from_date:
          Date.new(2026, 11, 5),
        to_date:
          Date.new(2026, 11, 30)
      )

    assert_equal 100.to_d,
                 result.opening_balance

    assert_equal 250.to_d,
                 result.total_debits

    assert_equal 0.to_d,
                 result.total_credits

    assert_equal 250.to_d,
                 result.net_movement

    assert_equal 350.to_d,
                 result.closing_balance

    assert_equal 1,
                 result.lines.size

    assert_equal 350.to_d,
                 result.lines.first.running_balance
  end

  test "uses credit normal balance correctly" do
    create_journal(
      entry_date:
        Date.new(2026, 11, 10),
      amount:
        400
    )

    result =
      Accounting::Reports::GeneralLedger.call(
        organization:
          @organization,
        ledger_account:
          @revenue
      )

    assert_equal 400.to_d,
                 result.closing_balance

    assert_equal 400.to_d,
                 result.total_credits
  end

  test "includes reversed original and reversal entry" do
    journal =
      create_journal(
        entry_date:
          Date.new(2026, 11, 10),
        amount:
          500
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
      Accounting::Reports::GeneralLedger.call(
        organization:
          @organization,
        ledger_account:
          @receivable
      )

    assert_equal 2,
                 result.lines.size

    assert_equal 500.to_d,
                 result.total_debits

    assert_equal 500.to_d,
                 result.total_credits

    assert_equal 0.to_d,
                 result.closing_balance
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
        200,
      branch:
        second_branch
    )

    result =
      Accounting::Reports::GeneralLedger.call(
        organization:
          @organization,
        ledger_account:
          @receivable,
        branch:
          second_branch
      )

    assert_equal 1,
                 result.lines.size

    assert_equal 200.to_d,
                 result.closing_balance
  end

  test "rejects account from another organization" do
    other_owner =
      create_user

    other_organization =
      provision_organization_for(
        other_owner
      )

    foreign_account =
      other_organization
        .ledger_accounts
        .find_by!(
          code: "1100"
        )

    assert_raises(
      ArgumentError
    ) do
      Accounting::Reports::GeneralLedger.call(
        organization:
          @organization,
        ledger_account:
          foreign_account
      )
    end
  end

  test "rejects invalid date range" do
    assert_raises(
      ArgumentError
    ) do
      Accounting::Reports::GeneralLedger.call(
        organization:
          @organization,
        ledger_account:
          @receivable,
        from_date:
          Date.new(2026, 12, 1),
        to_date:
          Date.new(2026, 11, 1)
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
        "General ledger test",
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
