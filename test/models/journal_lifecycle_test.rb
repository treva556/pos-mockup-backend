require "test_helper"

class JournalLifecycleTest <
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

  test "journal cannot be created already posted" do
    entry =
      JournalEntry.new(
        organization: @organization,
        created_by: @user,
        entry_number: "JE-999998",
        sequence_number: 999_998,
        entry_date: Date.current,
        status: "posted",
        posted_at: Time.current
      )

    assert_not entry.valid?

    assert_includes(
      entry.errors[:status],
      "must start as draft"
    )
  end

  test "draft cannot be directly changed to posted" do
    entry =
      create_draft

    entry.status =
      "posted"

    entry.posted_at =
      Time.current

    assert_not entry.save

    assert_includes(
      entry.errors[:status],
      "must be changed through the accounting lifecycle service"
    )

    assert entry.reload.status_draft?
  end

  test "posting service can perform controlled transition" do
    entry =
      create_draft

    Accounting::PostJournalEntry.call(
      journal_entry: entry
    )

    assert entry.reload.status_posted?
    assert entry.posted_at.present?
  end

  private

  def create_draft
    Accounting::CreateJournalEntry.call(
      organization: @organization,
      created_by: @user,
      entry_date: Date.current,
      description: "Lifecycle journal",
      post: false,
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
end
