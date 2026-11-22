require "test_helper"

class Accounting::ProfitAndLossControllerTest <
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
      organization: @organization,
      created_by: @owner,
      entry_date: Date.current,
      description: "P&L controller test",
      lines: [
        {
          ledger_account: @receivable,
          branch: @branch,
          debit: 500,
          credit: 0
        },
        {
          ledger_account: @revenue,
          branch: @branch,
          debit: 0,
          credit: 500
        }
      ]
    )
  end

  test "shows profit and loss report" do
    get accounting_profit_and_loss_path(
      from_date:
        Date.current.beginning_of_month.iso8601,
      to_date:
        Date.current.iso8601
    )

    assert_response :success

    assert_select(
      "h1",
      text: "Profit & Loss"
    )

    assert_select(
      "body",
      text: /Sales Revenue/
    )

    assert_select(
      "body",
      text: /500/
    )

    assert_select(
      "body",
      text: /Net Profit/
    )
  end

  test "filters report by branch" do
    get accounting_profit_and_loss_path(
      from_date:
        Date.current.beginning_of_month.iso8601,
      to_date:
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

    get accounting_profit_and_loss_path(
      branch_id:
        other_organization.main_branch.id
    )

    assert_response :not_found
  end

  test "shows error for invalid date range" do
    get accounting_profit_and_loss_path(
      from_date: "2026-12-31",
      to_date: "2026-11-01"
    )

    assert_response :success

    assert_select(
      "body",
      text:
        /From date cannot be after to date/
    )
  end
end
