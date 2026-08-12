require "test_helper"

class Accounting::JournalEngineRegressionTest <
  ActiveSupport::TestCase
  setup do
    @user =
      create_user

    @organization =
      provision_organization_for(
        @user
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

  test "same source cannot receive two journal entries" do
    source =
      create_source_transfer

    first =
      create_balanced_entry(
        source: source
      )

    assert first.status_posted?

    assert_raises(
      ActiveRecord::RecordInvalid
    ) do
      create_balanced_entry(
        source: source
      )
    end

    assert_equal(
      1,
      @organization
        .journal_entries
        .where(
          source: source
        )
        .count
    )
  end

  test "failed journal creation does not consume sequence number" do
    assert_raises(
      Accounting::PostJournalEntry::PostingError
    ) do
      Accounting::CreateJournalEntry.call(
        organization: @organization,
        created_by: @user,
        entry_date: Date.current,
        description: "Unbalanced journal",
        lines: [
          {
            ledger_account: @receivable,
            branch: @branch,
            debit: 1_000,
            credit: 0
          },
          {
            ledger_account: @revenue,
            branch: @branch,
            debit: 0,
            credit: 900
          }
        ]
      )
    end

    entry =
      create_balanced_entry

    assert_equal(
      "JE-000001",
      entry.entry_number
    )

    assert_equal(
      1,
      entry.sequence_number
    )
  end

  private

  def create_balanced_entry(
    source: nil
  )
    Accounting::CreateJournalEntry.call(
      organization: @organization,
      created_by: @user,
      source: source,
      entry_date: Date.current,
      description: "Balanced journal",
      lines: [
        {
          ledger_account: @receivable,
          branch: @branch,
          debit: 1_000,
          credit: 0
        },
        {
          ledger_account: @revenue,
          branch: @branch,
          debit: 0,
          credit: 1_000
        }
      ]
    )
  end

  def create_source_transfer
    from_account =
      create_money_account(
        organization: @organization,
        overrides: {
          name: "Journal Source Cash",
          opening_balance: 2_000
        }
      )

    to_account =
      create_money_account(
        organization: @organization,
        overrides: {
          name: "Journal Source Bank",
          opening_balance: 0
        }
      )

    create_money_transfer(
      organization: @organization,
      recorded_by: @user,
      from_account: from_account,
      to_account: to_account,
      overrides: {
        amount: 500
      }
    )
  end
end
