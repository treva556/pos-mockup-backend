require "test_helper"

class Settings::OrganizationsControllerTest <
  ActionDispatch::IntegrationTest
  test "owner can access organization settings" do
    owner = create_user
    provision_organization_for(owner)

    sign_in_as(owner)

    get edit_settings_organization_path

    assert_response :success
  end

  test "cashier cannot access organization settings" do
    owner = create_user
    organization = provision_organization_for(owner)

    cashier = create_user

    Membership.create!(
      user: cashier,
      organization: organization,
      branch: organization.main_branch,
      role: "cashier",
      active: true
    )

    sign_in_as(cashier)

    get edit_settings_organization_path

    assert_redirected_to dashboard_path
  end
end
