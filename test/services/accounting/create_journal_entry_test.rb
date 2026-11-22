require "test_helper"

class Accounting::CreateJournalEntryTest <
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

  test "creates and posts balanced journal" do
    entry =
      create_entry

    assert entry.persisted?
    assert entry.status_posted?

    assert_equal(
      "JE-000001",
      entry.entry_number
    )

    assert_equal(
      1,
      entry.sequence_number
    )

    assert_equal(
      2,
      entry.journal_lines.count
    )

    assert entry.balanced?
  end

  test "allocates sequential numbers" do
    first =
      create_entry

    second =
      create_entry(
        description:
          "Second journal"
      )

    assert_equal(
      "JE-000001",
      first.entry_number
    )

    assert_equal(
      "JE-000002",
      second.entry_number
    )

    assert_equal(
      2,
      second.sequence_number
    )
  end

  test "rolls back entry when journal is unbalanced" do
    assert_no_difference(
      "JournalEntry.count"
    ) do
      assert_raises(
        Accounting::PostJournalEntry::PostingError
      ) do
        Accounting::CreateJournalEntry.call(
          organization: @organization,
          created_by: @user,
          entry_date: Date.current,
          description: "Bad journal",
          lines: [
            {
              ledger_account:
                @receivable,
              branch:
                @branch,
              debit: 1_000,
              credit: 0
            },
            {
              ledger_account:
                @revenue,
              branch:
                @branch,
              debit: 0,
              credit: 900
            }
          ]
        )
      end
    end
  end

  private

  def create_entry(
    description: "Credit sale"
  )
    Accounting::CreateJournalEntry.call(
      organization: @organization,
      created_by: @user,
      entry_date: Date.current,
      description: description,
      lines: [
        {
          ledger_account:
            @receivable,
          branch:
            @branch,
          debit: 1_000,
          credit: 0
        },
        {
          ledger_account:
            @revenue,
          branch:
            @branch,
          debit: 0,
          credit: 1_000
        }
      ]
    )
  end
end

class Accounting::CreateJournalEntryClosedPeriodTest <
  ActiveSupport::TestCase
  setup do
    @owner =
      create_user

    @organization =
      provision_organization_for(
        @owner
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

  test "blocks journal creation inside closed accounting period" do
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

    assert_raises(
      Accounting::PostJournalEntry::PostingError
    ) do
      Accounting::CreateJournalEntry.call(
        organization: @organization,
        created_by: @owner,
        entry_date: Date.new(2026, 11, 15),
        description: "Closed period journal",
        lines: [
          {
            ledger_account: @receivable,
            branch: @branch,
            debit: 100,
            credit: 0
          },
          {
            ledger_account: @revenue,
            branch: @branch,
            debit: 0,
            credit: 100
          }
        ]
      )
    end
  end

  test "allows journal creation outside closed accounting period" do
    @organization
      .accounting_periods
      .create!(
        name: "October 2026",
        starts_on: Date.new(2026, 10, 1),
        ends_on: Date.new(2026, 10, 31),
        status: "closed",
        closed_at: Time.current,
        closed_by: @owner
      )

    journal =
      Accounting::CreateJournalEntry.call(
        organization: @organization,
        created_by: @owner,
        entry_date: Date.new(2026, 11, 15),
        description: "Open period journal",
        lines: [
          {
            ledger_account: @receivable,
            branch: @branch,
            debit: 100,
            credit: 0
          },
          {
            ledger_account: @revenue,
            branch: @branch,
            debit: 0,
            credit: 100
          }
        ]
      )

    assert journal.status_posted?
  end
end
