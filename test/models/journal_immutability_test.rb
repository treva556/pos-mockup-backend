require "test_helper"

class JournalImmutabilityTest <
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

    @entry =
      Accounting::CreateJournalEntry.call(
        organization: @organization,
        created_by: @user,
        entry_date: Date.current,
        description: "Posted journal",
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

  test "posted journal entry cannot be edited" do
    @entry.description =
      "Changed description"

    assert_not @entry.save

    assert_includes(
      @entry.errors[:base],
      "Posted or reversed journal entries cannot be changed"
    )
  end

  test "posted journal line cannot be edited" do
    line =
      @entry
        .journal_lines
        .first

    line.debit =
      500

    assert_not line.save

    assert_includes(
      line.errors[:journal_entry],
      "must be draft before journal lines can be changed"
    )
  end

  test "cannot add line to posted journal" do
    line =
      @entry
        .journal_lines
        .new(
          organization: @organization,
          ledger_account: @receivable,
          branch: @branch,
          line_number: 3,
          debit: 100,
          credit: 0
        )

    assert_not line.valid?

    assert_includes(
      line.errors[:journal_entry],
      "must be draft before journal lines can be changed"
    )
  end

  test "posted journal line cannot be deleted" do
    line =
      @entry
        .journal_lines
        .first

    assert_not line.destroy

    assert line.persisted?
  end

  test "posted journal entry cannot be deleted" do
    assert_not @entry.destroy

    assert @entry.persisted?
  end
end
