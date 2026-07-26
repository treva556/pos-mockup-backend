require "test_helper"

class BranchPaymentSettingsControllerTest <
  ActionDispatch::IntegrationTest
  setup do
    @owner = create_user
    @organization = provision_organization_for(@owner)
    @branch = @organization.main_branch

    @payment_method = create_payment_method(
      organization: @organization
    )

    @money_account = create_money_account(
      organization: @organization,
      overrides: {
        branch: @branch
      }
    )

    sign_in_as(@owner)
  end

  test "saves a branch payment default" do
    assert_difference(
      "BranchPaymentSetting.count",
      1
    ) do
      patch update_defaults_branch_payment_settings_path(
        branch_id: @branch.id
      ),
            params: {
              settings: {
                @payment_method.id.to_s => {
                  enabled: "1",
                  money_account_id:
                    @money_account.id.to_s
                }
              }
            }
    end

    setting =
      @organization.branch_payment_settings.last

    assert_equal @branch, setting.branch
    assert_equal @payment_method,
                 setting.payment_method
    assert_equal @money_account,
                 setting.money_account

    assert_redirected_to branch_payment_settings_path(
      branch_id: @branch.id
    )
  end

  test "rejects another organizations account" do
    other_organization =
      provision_organization_for(create_user)

    foreign_account = create_money_account(
      organization: other_organization
    )

    patch update_defaults_branch_payment_settings_path(
      branch_id: @branch.id
    ),
          params: {
            settings: {
              @payment_method.id.to_s => {
                enabled: "1",
                money_account_id:
                  foreign_account.id.to_s
              }
            }
          }

    assert_response :not_found
  end
end
