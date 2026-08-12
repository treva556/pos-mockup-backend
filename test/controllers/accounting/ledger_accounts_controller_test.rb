require "test_helper"

class Accounting::LedgerAccountsControllerTest <
  ActionDispatch::IntegrationTest
  setup do
    @owner =
      create_user

    @organization =
      provision_organization_for(
        @owner
      )

    Accounting::ProvisionDefaultChart
      .new(
        organization: @organization
      )
      .call
  end

  test "owner can view chart of accounts" do
    sign_in_as(
      @owner
    )

    get accounting_ledger_accounts_path

    assert_response :success

    assert_select "h1",
                  "Chart of Accounts"

    assert_select "td",
                  text: /Accounts Receivable/
  end

  test "owner can create custom ledger account" do
    sign_in_as(
      @owner
    )

    assert_difference(
      "@organization.ledger_accounts.count",
      1
    ) do
      post accounting_ledger_accounts_path,
           params: {
             ledger_account: {
               code: "6060",
               name: "Advertising Expense",
               account_type: "expense",
               normal_balance: "debit",
               report_group: "operating_expense",
               postable: "1"
             }
           }
    end

    account =
      @organization
        .ledger_accounts
        .find_by!(
          code: "6060"
        )

    assert_equal(
      "Advertising Expense",
      account.name
    )

    assert_not account.system_account?

    assert account.active?

    assert_redirected_to(
      accounting_ledger_accounts_path
    )
  end

  test "manager can view but cannot manage chart of accounts" do
    manager =
      create_user

    Membership.create!(
      user: manager,
      organization: @organization,
      role: "manager",
      active: true
    )

    sign_in_as(
      manager
    )

    get accounting_ledger_accounts_path

    assert_response :success

    get new_accounting_ledger_account_path

    assert_redirected_to(
      accounting_ledger_accounts_path
    )
  end

  test "accountant can manage chart of accounts" do
    accountant =
      create_user

    Membership.create!(
      user: accountant,
      organization: @organization,
      role: "accountant",
      active: true
    )

    sign_in_as(
      accountant
    )

    get new_accounting_ledger_account_path

    assert_response :success
  end

  test "cashier cannot view accounting" do
    cashier =
      create_user

    Membership.create!(
      user: cashier,
      organization: @organization,
      branch: @organization.main_branch,
      role: "cashier",
      active: true
    )

    sign_in_as(
      cashier
    )

    get accounting_ledger_accounts_path

    assert_redirected_to(
      dashboard_path
    )
  end

  test "stock clerk cannot view accounting" do
    stock_clerk =
      create_user

    Membership.create!(
      user: stock_clerk,
      organization: @organization,
      branch: @organization.main_branch,
      role: "stock_clerk",
      active: true
    )

    sign_in_as(
      stock_clerk
    )

    get accounting_ledger_accounts_path

    assert_redirected_to(
      dashboard_path
    )
  end

  test "cannot access another organizations ledger account" do
    other_owner =
      create_user

    other_organization =
      provision_organization_for(
        other_owner
      )

    foreign_account =
      other_organization
        .ledger_accounts
        .create!(
          code: "7000",
          name: "Foreign Expense",
          account_type: "expense",
          normal_balance: "debit",
          report_group: "other_expense",
          postable: true,
          active: true,
          system_account: false
        )

    sign_in_as(
      @owner
    )

    get edit_accounting_ledger_account_path(
      foreign_account
    )

    assert_response :not_found
  end

  test "system account cannot be edited through controller" do
    system_account =
      @organization
        .ledger_accounts
        .find_by!(
          code: "1100"
        )

    sign_in_as(
      @owner
    )

    get edit_accounting_ledger_account_path(
      system_account
    )

    assert_redirected_to(
      accounting_ledger_accounts_path
    )

    follow_redirect!

    assert_match(
      "System accounts cannot be changed",
      response.body
    )
  end

  test "system account cannot be toggled through controller" do
    system_account =
      @organization
        .ledger_accounts
        .find_by!(
          code: "1200"
        )

    sign_in_as(
      @owner
    )

    patch toggle_status_accounting_ledger_account_path(
      system_account
    )

    assert_redirected_to(
      accounting_ledger_accounts_path
    )

    assert system_account.reload.active?
  end

  test "custom account may be disabled and enabled" do
    account =
      @organization
        .ledger_accounts
        .create!(
          code: "6060",
          name: "Advertising Expense",
          account_type: "expense",
          normal_balance: "debit",
          report_group: "operating_expense",
          postable: true,
          active: true,
          system_account: false
        )

    sign_in_as(
      @owner
    )

    patch toggle_status_accounting_ledger_account_path(
      account
    )

    assert_redirected_to(
      accounting_ledger_accounts_path
    )

    assert_not account.reload.active?

    patch toggle_status_accounting_ledger_account_path(
      account
    )

    assert account.reload.active?
  end
end
