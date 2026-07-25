require "test_helper"

class DashboardsControllerTest < ActionDispatch::IntegrationTest
  test "logged out user cannot access dashboard" do
    get dashboard_path

    assert_redirected_to login_path
  end

  test "logged in member can access dashboard" do
    user = create_user
    provision_organization_for(user)

    sign_in_as(user)

    assert_redirected_to dashboard_path

    get dashboard_path

    assert_response :success
  end
end
