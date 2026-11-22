require "test_helper"

class Accounting::TrialBalanceControllerTest <
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
        "Trial balance controller test",
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

  test "shows trial balance report" do
    get accounting_trial_balance_path(
      as_of_date:
        Date.current.iso8601
    )

    assert_response :success

    assert_select(
      "h1",
      text:
        "Trial Balance"
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

    assert_select(
      "body",
      text:
        /Trial balance is balanced/
    )
  end

  test "filters trial balance by branch" do
    get accounting_trial_balance_path(
      as_of_date:
        Date.current.iso8601,
      branch_id:
        @branch.id
    )

    assert_response :success

    assert_select(
      "body",
      text:
        /#{Regexp.escape(@branch.name)}/
    )
  end

  test "cannot use another organizations branch" do
    other_owner =
      create_user

    other_organization =
      provision_organization_for(
        other_owner
      )

    get accounting_trial_balance_path(
      branch_id:
        other_organization.main_branch.id
    )

    assert_response :not_found
  end
end
