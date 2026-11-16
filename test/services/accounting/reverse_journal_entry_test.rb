require "test_helper"

class Accounting::ReverseJournalEntryTest <
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
        description: "Original journal",
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

  test "creates equal and opposite reversal" do
    reversal =
      Accounting::ReverseJournalEntry.call(
        journal_entry: @entry,
        reversed_by: @user
      )

    assert reversal.status_posted?

    assert_equal(
      @entry.id,
      reversal.reversal_of_id
    )

    assert_equal(
      reversal.id,
      @entry.reload.reversal_entry.id
    )

    assert @entry.status_reversed?

    assert @entry.reversed_at.present?

    original_debit =
      @entry
        .journal_lines
        .find_by!(
          ledger_account: @receivable
        )

    reversed_credit =
      reversal
        .journal_lines
        .find_by!(
          ledger_account: @receivable
        )

    assert_equal(
      original_debit.debit,
      reversed_credit.credit
    )

    original_credit =
      @entry
        .journal_lines
        .find_by!(
          ledger_account: @revenue
        )

    reversed_debit =
      reversal
        .journal_lines
        .find_by!(
          ledger_account: @revenue
        )

    assert_equal(
      original_credit.credit,
      reversed_debit.debit
    )

    assert reversal.balanced?
  end

  test "cannot reverse draft journal" do
    draft =
      Accounting::CreateJournalEntry.call(
        organization: @organization,
        created_by: @user,
        entry_date: Date.current,
        description: "Draft journal",
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
        ],
        post: false
      )

    assert_raises(
      Accounting::ReverseJournalEntry::ReversalError
    ) do
      Accounting::ReverseJournalEntry.call(
        journal_entry: draft,
        reversed_by: @user
      )
    end
  end

  test "cannot reverse same journal twice" do
    Accounting::ReverseJournalEntry.call(
      journal_entry: @entry,
      reversed_by: @user
    )

    assert_raises(
      Accounting::ReverseJournalEntry::ReversalError
    ) do
      Accounting::ReverseJournalEntry.call(
        journal_entry: @entry.reload,
        reversed_by: @user
      )
    end
  end

  test "cannot reverse a reversal journal" do
    reversal =
      Accounting::ReverseJournalEntry.call(
        journal_entry: @entry,
        reversed_by: @user
      )

    assert_raises(
      Accounting::ReverseJournalEntry::ReversalError
    ) do
      Accounting::ReverseJournalEntry.call(
        journal_entry: reversal,
        reversed_by: @user
      )
    end
  end

  test "reversal date cannot precede original date" do
    assert_raises(
      Accounting::ReverseJournalEntry::ReversalError
    ) do
      Accounting::ReverseJournalEntry.call(
        journal_entry: @entry,
        reversed_by: @user,
        reversal_date:
          @entry.entry_date - 1.day
      )
    end

    assert @entry.reload.status_posted?
    assert_nil @entry.reversal_entry
  end
end
