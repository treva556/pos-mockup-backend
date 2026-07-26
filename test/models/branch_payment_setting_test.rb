require "test_helper"

class BranchPaymentSettingTest <
  ActiveSupport::TestCase
  setup do
    @organization =
      provision_organization_for(create_user)

    @branch = @organization.main_branch

    @cash_method = create_payment_method(
      organization: @organization,
      overrides: {
        name: "Cash",
        code: "CASH",
        payment_type: "cash"
      }
    )

    @cash_account = create_money_account(
      organization: @organization,
      overrides: {
        name: "Main Cash Till",
        branch: @branch
      }
    )
  end

  test "accepts a valid branch payment default" do
    setting =
      @organization.branch_payment_settings.new(
        branch: @branch,
        payment_method: @cash_method,
        money_account: @cash_account,
        enabled: true
      )

    assert setting.valid?
  end

  test "enabled cash method requires an account" do
    setting =
      @organization.branch_payment_settings.new(
        branch: @branch,
        payment_method: @cash_method,
        money_account: nil,
        enabled: true
      )

    assert_not setting.valid?

    assert_includes(
      setting.errors[:money_account],
      "must be selected for this payment method"
    )
  end

  test "credit may be enabled without an account" do
    credit_method = create_payment_method(
      organization: @organization,
      overrides: {
        name: "Credit",
        code: "CREDIT",
        payment_type: "credit"
      }
    )

    setting =
      @organization.branch_payment_settings.new(
        branch: @branch,
        payment_method: credit_method,
        money_account: nil,
        enabled: true
      )

    assert setting.valid?
  end

  test "rejects an account from another organization" do
    other_organization =
      provision_organization_for(create_user)

    foreign_account = create_money_account(
      organization: other_organization
    )

    setting =
      @organization.branch_payment_settings.new(
        branch: @branch,
        payment_method: @cash_method,
        money_account: foreign_account,
        enabled: true
      )

    assert_not setting.valid?

    assert_includes(
      setting.errors[:money_account],
      "must belong to the same organization"
    )
  end

  test "rejects an account belonging to another branch" do
    second_branch =
      create_branch(organization: @organization)

    second_branch_account = create_money_account(
      organization: @organization,
      overrides: {
        branch: second_branch
      }
    )

    setting =
      @organization.branch_payment_settings.new(
        branch: @branch,
        payment_method: @cash_method,
        money_account: second_branch_account,
        enabled: true
      )

    assert_not setting.valid?

    assert_includes(
      setting.errors[:money_account],
      "must be organization-wide or belong to the selected branch"
    )
  end
end
