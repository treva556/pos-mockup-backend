require "test_helper"

class AccountingNavigationTest <
  ActionDispatch::IntegrationTest
  test "accounting user sees accounting navigation" do
    owner =
      create_user

    provision_organization_for(
      owner
    )

    sign_in_as(
      owner
    )

    get dashboard_path

    assert_response :success

    assert_select(
      "a[href='#{accounting_ledger_accounts_path}']",
      text: "Accounting"
    )
  end

  test "cashier does not see accounting navigation" do
    owner =
      create_user

    organization =
      provision_organization_for(
        owner
      )

    cashier =
      create_user

    Membership.create!(
      user: cashier,
      organization: organization,
      branch: organization.main_branch,
      role: "cashier",
      active: true
    )

    sign_in_as(
      cashier
    )

    get dashboard_path

    assert_response :success

    assert_select(
      "a[href='#{accounting_ledger_accounts_path}']",
      count: 0
    )
  end
end
