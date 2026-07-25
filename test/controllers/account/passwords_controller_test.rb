require "test_helper"

class Account::PasswordsControllerTest <
  ActionDispatch::IntegrationTest
  test "temporary password user is redirected to password change" do
    user = create_user(
      must_change_password: true
    )

    provision_organization_for(user)

    sign_in_as(user)

    assert_redirected_to edit_account_password_path

    get dashboard_path

    assert_redirected_to edit_account_password_path
  end

  test "successful password change clears temporary password flag" do
    user = create_user(
      must_change_password: true
    )

    provision_organization_for(user)

    sign_in_as(user)

    patch account_password_path,
          params: {
            password_change: {
              current_password: "Password123!",
              password: "NewPassword123!",
              password_confirmation:
                "NewPassword123!"
            }
          }

    assert_redirected_to dashboard_path
    assert_not user.reload.must_change_password?

    assert user.authenticate(
      "NewPassword123!"
    )
  end
end
