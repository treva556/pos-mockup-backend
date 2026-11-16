require "test_helper"

class Accounting::JournalEntriesControllerTest <
  ActionDispatch::IntegrationTest
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

    sign_in_as(
      @owner
    )
  end

  test "index displays organization journal entries" do
    journal =
      create_journal(
        description:
          "Journal browser test"
      )

    get accounting_journal_entries_path

    assert_response :success

    assert_select(
      "body",
      text:
        /#{Regexp.escape(journal.entry_number)}/
    )

    assert_select(
      "body",
      text:
        /Journal browser test/
    )
  end

  test "show displays journal lines" do
    journal =
      create_journal(
        description:
          "Journal detail test"
      )

    get accounting_journal_entry_path(
      journal
    )

    assert_response :success

    assert_select(
      "body",
      text:
        /#{Regexp.escape(journal.entry_number)}/
    )

    assert_select(
      "body",
      text:
        /Accounts Receivable/
    )

    assert_select(
      "body",
      text:
        /Sales Revenue/
    )
  end

  test "cannot access another organizations journal" do
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

    foreign_journal =
      Accounting::CreateJournalEntry.call(
        organization:
          other_organization,
        created_by:
          other_owner,
        entry_date:
          Date.current,
        description:
          "Foreign journal",
        lines: [
          {
            ledger_account:
              other_receivable,
            branch:
              other_organization.main_branch,
            debit: 100,
            credit: 0
          },
          {
            ledger_account:
              other_revenue,
            branch:
              other_organization.main_branch,
            debit: 0,
            credit: 100
          }
        ]
      )

    get accounting_journal_entry_path(
      foreign_journal
    )

    assert_response :not_found
  end

  test "filters journals by status" do
    create_journal(
      description:
        "Posted journal"
    )

    get accounting_journal_entries_path(
      status: "posted"
    )

    assert_response :success

    assert_select(
      "body",
      text:
        /Posted journal/
    )
  end

  private

  def create_journal(
    description:
  )
    Accounting::CreateJournalEntry.call(
      organization:
        @organization,
      created_by:
        @owner,
      entry_date:
        Date.current,
      description:
        description,
      lines: [
        {
          ledger_account:
            @receivable,
          branch:
            @branch,
          debit: 250,
          credit: 0
        },
        {
          ledger_account:
            @revenue,
          branch:
            @branch,
          debit: 0,
          credit: 250
        }
      ]
    )
  end
end
