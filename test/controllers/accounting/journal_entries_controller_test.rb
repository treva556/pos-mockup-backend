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

  test "new displays manual journal form" do
    get new_accounting_journal_entry_path

    assert_response :success

    assert_select(
      "h1",
      text: "New Manual Journal"
    )
  end

  test "creates and posts balanced manual journal" do
    assert_difference(
      -> {
        @organization
          .journal_entries
          .count
      },
      1
    ) do
      post accounting_journal_entries_path,
           params: {
             manual_journal: {
               entry_date:
                 Date.current.iso8601,
               description:
                 "Manual journal test",
               lines: {
                 "0" => {
                   ledger_account_id:
                     @receivable.id,
                   branch_id:
                     @branch.id,
                   description:
                     "Manual debit",
                   debit: "300",
                   credit: ""
                 },
                 "1" => {
                   ledger_account_id:
                     @revenue.id,
                   branch_id:
                     @branch.id,
                   description:
                     "Manual credit",
                   debit: "",
                   credit: "300"
                 }
               }
             }
           }
    end

    journal =
      @organization
        .journal_entries
        .order(:id)
        .last

    assert journal.status_posted?
    assert_equal 300.to_d,
                 journal.total_debits
    assert_equal 300.to_d,
                 journal.total_credits

    assert_redirected_to(
      accounting_journal_entry_path(
        journal
      )
    )
  end

  test "rejects unbalanced manual journal" do
    assert_no_difference(
      -> {
        @organization
          .journal_entries
          .count
      }
    ) do
      post accounting_journal_entries_path,
           params: {
             manual_journal: {
               entry_date:
                 Date.current.iso8601,
               description:
                 "Unbalanced journal",
               lines: {
                 "0" => {
                   ledger_account_id:
                     @receivable.id,
                   branch_id:
                     @branch.id,
                   debit: "300",
                   credit: ""
                 },
                 "1" => {
                   ledger_account_id:
                     @revenue.id,
                   branch_id:
                     @branch.id,
                   debit: "",
                   credit: "200"
                 }
               }
             }
           }
    end

    assert_response :unprocessable_entity

    assert_select(
      "body",
      text:
        /debits must equal credits/i
    )
  end

  test "rejects manual line without ledger account" do
    assert_no_difference(
      -> {
        @organization
          .journal_entries
          .count
      }
    ) do
      post accounting_journal_entries_path,
           params: {
             manual_journal: {
               entry_date:
                 Date.current.iso8601,
               description:
                 "Missing account",
               lines: {
                 "0" => {
                   ledger_account_id: "",
                   branch_id:
                     @branch.id,
                   debit: "300",
                   credit: ""
                 },
                 "1" => {
                   ledger_account_id:
                     @revenue.id,
                   branch_id:
                     @branch.id,
                   debit: "",
                   credit: "300"
                 }
               }
             }
           }
    end

    assert_response :unprocessable_entity

    assert_select(
      "body",
      text:
        /Each journal line must select an account/
    )
  end

  test "cannot use another organizations ledger account" do
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

    assert_no_difference(
      -> {
        @organization
          .journal_entries
          .count
      }
    ) do
      post accounting_journal_entries_path,
           params: {
             manual_journal: {
               entry_date:
                 Date.current.iso8601,
               description:
                 "Foreign account attempt",
               lines: {
                 "0" => {
                   ledger_account_id:
                     foreign_account.id,
                   branch_id:
                     @branch.id,
                   debit: "300",
                   credit: ""
                 },
                 "1" => {
                   ledger_account_id:
                     @revenue.id,
                   branch_id:
                     @branch.id,
                   debit: "",
                   credit: "300"
                 }
               }
             }
           }
    end

    assert_response :not_found
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
