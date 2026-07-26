require "test_helper"

class PaymentMethodTest < ActiveSupport::TestCase
  setup do
    @organization =
      provision_organization_for(create_user)
  end

  test "normalizes name and code" do
    method = create_payment_method(
      organization: @organization,
      overrides: {
        name: "  M-Pesa  ",
        code: "  mpesa  ",
        payment_type: "mobile_money"
      }
    )

    assert_equal "M-Pesa", method.name
    assert_equal "MPESA", method.code
  end

  test "code must be unique within an organization" do
    create_payment_method(
      organization: @organization,
      overrides: {
        name: "First Cash",
        code: "CASH"
      }
    )

    duplicate = @organization.payment_methods.new(
      name: "Second Cash",
      code: "cash",
      payment_type: "cash"
    )

    assert_not duplicate.valid?

    assert_includes(
      duplicate.errors[:code],
      "has already been taken"
    )
  end

  test "different organizations may use the same code" do
    other_organization =
      provision_organization_for(create_user)

    create_payment_method(
      organization: @organization,
      overrides: {
        name: "Cash",
        code: "CASH"
      }
    )

    method = other_organization.payment_methods.new(
      name: "Cash",
      code: "CASH",
      payment_type: "cash"
    )

    assert method.valid?
  end

  test "credit does not require a money account" do
    method = create_payment_method(
      organization: @organization,
      overrides: {
        payment_type: "credit"
      }
    )

    assert_not method.money_account_required?
  end
end
