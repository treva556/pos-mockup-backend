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
