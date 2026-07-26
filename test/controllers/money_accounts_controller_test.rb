require "test_helper"

class MoneyAccountsControllerTest <
  ActionDispatch::IntegrationTest
  setup do
    @owner = create_user
    @organization = provision_organization_for(@owner)
  end

  test "creates account in the current organization" do
    sign_in_as(@owner)

    assert_difference("MoneyAccount.count", 1) do
      post money_accounts_path,
           params: {
             money_account: {
               name: "New Cash Account",
               account_type: "cash",
               opening_balance: 0,
               can_receive: "1",
               can_pay: "1"
             }
           }
    end

    account = @organization.money_accounts.order(:id).last

    assert_equal @organization, account.organization
    assert_redirected_to money_account_path(account)
  end

  test "cannot access another organizations account" do
    other_organization =
      provision_organization_for(create_user)

    foreign_account = create_money_account(
      organization: other_organization
    )

    sign_in_as(@owner)

    get money_account_path(foreign_account)

    assert_response :not_found
  end

  test "cashier cannot manage money accounts" do
    cashier = create_user

    Membership.create!(
      user: cashier,
      organization: @organization,
      branch: @organization.main_branch,
      role: "cashier",
      active: true
    )

    sign_in_as(cashier)

    get money_accounts_path

    assert_redirected_to dashboard_path
  end
end
