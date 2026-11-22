require "test_helper"

class Accounting::AccountingReportsRegressionTest <
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

  test "general ledger closing balance agrees with trial balance account balance" do
    create_journal(
      entry_date:
        Date.new(2026, 11, 10),
      amount:
        500
    )

    create_journal(
      entry_date:
        Date.new(2026, 11, 12),
      amount:
        300
    )

    general_ledger =
      Accounting::Reports::GeneralLedger.call(
        organization:
          @organization,
        ledger_account:
          @receivable,
        to_date:
          Date.new(2026, 11, 30)
      )

    trial_balance =
      Accounting::Reports::TrialBalance.call(
        organization:
          @organization,
        as_of_date:
          Date.new(2026, 11, 30)
      )

    receivable_row =
      trial_balance.rows.find {
        |row|
        row.ledger_account.id ==
          @receivable.id
      }

    trial_balance_amount =
      receivable_row.debit -
      receivable_row.credit

    assert_equal general_ledger.closing_balance,
                 trial_balance_amount
  end

  test "trial balance remains balanced after multiple journals" do
    create_journal(
      entry_date:
        Date.new(2026, 11, 10),
      amount:
        200
    )

    create_journal(
      entry_date:
        Date.new(2026, 11, 11),
      amount:
        350
    )

    result =
      Accounting::Reports::TrialBalance.call(
        organization:
          @organization,
        as_of_date:
          Date.new(2026, 11, 30)
      )

    assert result.balanced

    assert_equal result.total_debits,
                 result.total_credits
  end

  test "reversal neutralizes balances in both reports" do
    journal =
      create_journal(
        entry_date:
          Date.new(2026, 11, 10),
        amount:
          600
      )

    Accounting::ReverseJournalEntry.call(
      journal_entry:
        journal,
      reversed_by:
        @owner,
      reversal_date:
        Date.new(2026, 11, 11)
    )

    general_ledger =
      Accounting::Reports::GeneralLedger.call(
        organization:
          @organization,
        ledger_account:
          @receivable,
        to_date:
          Date.new(2026, 11, 30)
      )

    trial_balance =
      Accounting::Reports::TrialBalance.call(
        organization:
          @organization,
        as_of_date:
          Date.new(2026, 11, 30)
      )

    assert_equal 0.to_d,
                 general_ledger.closing_balance

    assert trial_balance.balanced

    assert_empty trial_balance.rows
  end

  test "reports respect branch isolation" do
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
        400,
      branch:
        second_branch
    )

    ledger =
      Accounting::Reports::GeneralLedger.call(
        organization:
          @organization,
        ledger_account:
          @receivable,
        branch:
          second_branch
      )

    trial_balance =
      Accounting::Reports::TrialBalance.call(
        organization:
          @organization,
        branch:
          second_branch
      )

    assert_equal 400.to_d,
                 ledger.closing_balance

    assert_equal 400.to_d,
                 trial_balance.total_debits

    assert_equal 400.to_d,
                 trial_balance.total_credits
  end

  test "reports do not include another organizations journals" do
    create_journal(
      entry_date:
        Date.new(2026, 11, 10),
      amount:
        250
    )

    other_owner =
      create_user

    other_organization =
      provision_organization_for(
        other_owner
      )

    other_receivable =
      other_organization
        .ledger_accounts
        .find_by!(
          code: "1100"
        )

    other_revenue =
      other_organization
        .ledger_accounts
        .find_by!(
          code: "4010"
        )

    Accounting::CreateJournalEntry.call(
      organization:
        other_organization,
      created_by:
        other_owner,
      entry_date:
        Date.new(2026, 11, 10),
      description:
        "Foreign report journal",
      lines: [
        {
          ledger_account:
            other_receivable,
          branch:
            other_organization.main_branch,
          debit: 900,
          credit: 0
        },
        {
          ledger_account:
            other_revenue,
          branch:
            other_organization.main_branch,
          debit: 0,
          credit: 900
        }
      ]
    )

    result =
      Accounting::Reports::TrialBalance.call(
        organization:
          @organization
      )

    assert_equal 250.to_d,
                 result.total_debits

    assert_equal 250.to_d,
                 result.total_credits
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
        "Accounting reports regression",
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
