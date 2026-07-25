require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "active user with organization can log in" do
    user = create_user
    provision_organization_for(user)

    sign_in_as(user)

    assert_redirected_to dashboard_path
  end

  test "incorrect password is rejected" do
    user = create_user
    provision_organization_for(user)

    sign_in_as(
      user,
      password: "IncorrectPassword123!"
    )

    assert_response :unprocessable_entity

    assert_match(
      "Invalid email or password.",
      response.body
    )
  end

  test "inactive user cannot log in" do
    user = create_user(active: false)
    provision_organization_for(user)

    sign_in_as(user)

    assert_response :unprocessable_entity

    assert_match(
      "Invalid email or password.",
      response.body
    )
  end
end
