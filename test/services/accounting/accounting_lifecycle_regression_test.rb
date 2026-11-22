require "test_helper"

class Accounting::AccountingLifecycleRegressionTest <
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

  test "manual journal posts balanced and can be reversed" do
    journal =
      create_manual_journal(
        entry_date:
          Date.new(2026, 11, 10),
        amount: 500
      )

    assert journal.status_posted?
    assert journal.balanced?

    reversal =
      Accounting::ReverseJournalEntry.call(
        journal_entry: journal,
        reversed_by: @owner,
        reversal_date:
          Date.new(2026, 11, 11)
      )

    journal.reload

    assert journal.status_reversed?
    assert reversal.status_posted?
    assert_equal journal.id,
                 reversal.reversal_of_id

    assert_equal journal.total_debits,
                 reversal.total_credits

    assert_equal journal.total_credits,
                 reversal.total_debits
  end

  test "closed period blocks new journal posting" do
    close_period(
      name: "November 2026",
      starts_on:
        Date.new(2026, 11, 1),
      ends_on:
        Date.new(2026, 11, 30)
    )

    assert_no_difference(
      -> {
        @organization
          .journal_entries
          .count
      }
    ) do
      assert_raises(
        Accounting::PostJournalEntry::PostingError
      ) do
        create_manual_journal(
          entry_date:
            Date.new(2026, 11, 15),
          amount: 250
        )
      end
    end
  end

  test "closed period does not block later open dates" do
    close_period(
      name: "October 2026",
      starts_on:
        Date.new(2026, 10, 1),
      ends_on:
        Date.new(2026, 10, 31)
    )

    journal =
      create_manual_journal(
        entry_date:
          Date.new(2026, 11, 15),
        amount: 250
      )

    assert journal.status_posted?
    assert journal.balanced?
  end

  test "closed period blocks reversal dated inside it" do
    journal =
      create_manual_journal(
        entry_date:
          Date.new(2026, 11, 5),
        amount: 300
      )

    close_period(
      name: "November 2026",
      starts_on:
        Date.new(2026, 11, 1),
      ends_on:
        Date.new(2026, 11, 30)
    )

    assert_no_difference(
      -> {
        @organization
          .journal_entries
          .count
      }
    ) do
      assert_raises(
        Accounting::ReverseJournalEntry::ReversalError
      ) do
        Accounting::ReverseJournalEntry.call(
          journal_entry: journal,
          reversed_by: @owner,
          reversal_date:
            Date.new(2026, 11, 20)
        )
      end
    end

    assert journal.reload.status_posted?
  end

  test "organization cannot post with another organizations account" do
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
      ActiveRecord::RecordInvalid
    ) do
      Accounting::CreateJournalEntry.call(
        organization:
          @organization,
        created_by:
          @owner,
        entry_date:
          Date.current,
        description:
          "Cross organization attempt",
        lines: [
          {
            ledger_account:
              foreign_account,
            branch:
              @branch,
            debit: 100,
            credit: 0
          },
          {
            ledger_account:
              @revenue,
            branch:
              @branch,
            debit: 0,
            credit: 100
          }
        ]
      )
    end
  end

  test "failed posting rolls back entire journal" do
    assert_no_difference(
      -> {
        @organization
          .journal_entries
          .count
      }
    ) do
      assert_raises(
        Accounting::PostJournalEntry::PostingError
      ) do
        Accounting::CreateJournalEntry.call(
          organization:
            @organization,
          created_by:
            @owner,
          entry_date:
            Date.current,
          description:
            "Unbalanced regression",
          lines: [
            {
              ledger_account:
                @receivable,
              branch:
                @branch,
              debit: 500,
              credit: 0
            },
            {
              ledger_account:
                @revenue,
              branch:
                @branch,
              debit: 0,
              credit: 400
            }
          ]
        )
      end
    end
  end

  private

  def create_manual_journal(
    entry_date:,
    amount:
  )
    Accounting::CreateJournalEntry.call(
      organization:
        @organization,
      created_by:
        @owner,
      entry_date:
        entry_date,
      description:
        "Lifecycle regression journal",
      lines: [
        {
          ledger_account:
            @receivable,
          branch:
            @branch,
          debit:
            amount,
          credit: 0
        },
        {
          ledger_account:
            @revenue,
          branch:
            @branch,
          debit: 0,
          credit:
            amount
        }
      ]
    )
  end

  def close_period(
    name:,
    starts_on:,
    ends_on:
  )
    @organization
      .accounting_periods
      .create!(
        name:
          name,
        starts_on:
          starts_on,
        ends_on:
          ends_on,
        status:
          "closed",
        closed_at:
          Time.current,
        closed_by:
          @owner
      )
  end
end
