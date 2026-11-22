require "test_helper"

class Accounting::GeneralLedgerControllerTest <
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

    Accounting::CreateJournalEntry.call(
      organization:
        @organization,
      created_by:
        @owner,
      entry_date:
        Date.current,
      description:
        "General ledger controller test",
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
          credit: 500
        }
      ]
    )
  end

  test "shows general ledger report" do
    get accounting_general_ledger_path(
      ledger_account_id:
        @receivable.id,
      from_date:
        Date.current.beginning_of_month.iso8601,
      to_date:
        Date.current.iso8601
    )

    assert_response :success

    assert_select(
      "h1",
      text:
        "General Ledger"
    )

    assert_select(
      "body",
      text:
        /Accounts Receivable/
    )

    assert_select(
      "body",
      text:
        /500/
    )
  end

  test "filters general ledger by branch" do
    get accounting_general_ledger_path(
      ledger_account_id:
        @receivable.id,
      branch_id:
        @branch.id,
      from_date:
        Date.current.beginning_of_month.iso8601,
      to_date:
        Date.current.iso8601
    )

    assert_response :success

    assert_select(
      "body",
      text:
        /#{Regexp.escape(@branch.name)}/
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

    get accounting_general_ledger_path(
      ledger_account_id:
        foreign_account.id
    )

    assert_response :not_found
  end
end
