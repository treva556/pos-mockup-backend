require "test_helper"

class Accounting::PostJournalEntryTest <
  ActiveSupport::TestCase
  setup do
    @user =
      create_user

    @organization =
      provision_organization_for(
        @user
      )

    @entry =
      JournalEntry.create!(
        organization: @organization,
        created_by: @user,
        entry_number: "JE-000001",
        sequence_number: 1,
        entry_date: Date.current,
        status: "draft"
      )

    @debit_account =
      @organization
        .ledger_accounts
        .find_by!(
          code: "1100"
        )

    @credit_account =
      @organization
        .ledger_accounts
        .find_by!(
          code: "4010"
        )
  end

  test "posts balanced journal entry" do
    add_line(
      account: @debit_account,
      debit: 1_000
    )

    add_line(
      account: @credit_account,
      credit: 1_000
    )

    result =
      Accounting::PostJournalEntry.call(
        journal_entry: @entry
      )

    assert result.status_posted?
    assert result.posted_at.present?

    assert_equal(
      1_000.to_d,
      result.total_debits
    )

    assert_equal(
      1_000.to_d,
      result.total_credits
    )
  end

  test "rejects unbalanced journal entry" do
    add_line(
      account: @debit_account,
      debit: 1_000
    )

    add_line(
      account: @credit_account,
      credit: 900
    )

    error =
      assert_raises(
        Accounting::PostJournalEntry::PostingError
      ) do
        Accounting::PostJournalEntry.call(
          journal_entry: @entry
        )
      end

    assert_equal(
      "Journal entry debits must equal credits",
      error.message
    )

    assert @entry.reload.status_draft?
    assert_nil @entry.posted_at
  end

  test "requires at least two lines" do
    add_line(
      account: @debit_account,
      debit: 1_000
    )

    assert_raises(
      Accounting::PostJournalEntry::PostingError
    ) do
      Accounting::PostJournalEntry.call(
        journal_entry: @entry
      )
    end

    assert @entry.reload.status_draft?
  end

  test "posted journal cannot be posted again" do
    add_line(
      account: @debit_account,
      debit: 500
    )

    add_line(
      account: @credit_account,
      credit: 500
    )

    Accounting::PostJournalEntry.call(
      journal_entry: @entry
    )

    assert_raises(
      Accounting::PostJournalEntry::PostingError
    ) do
      Accounting::PostJournalEntry.call(
        journal_entry: @entry
      )
    end
  end

  private

  def add_line(
    account:,
    debit: 0,
    credit: 0
  )
    @entry
      .journal_lines
      .create!(
        organization:
          @organization,
        ledger_account:
          account,
        branch:
          @organization.main_branch,
        line_number:
          @entry.journal_lines.count + 1,
        debit: debit,
        credit: credit
      )
  end
end
