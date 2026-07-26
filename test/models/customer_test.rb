require "test_helper"

class CustomerTest < ActiveSupport::TestCase
  test "normalizes customer details" do
    organization = create_organization

    customer = organization.customers.create!(
      name: "  John Customer  ",
      phone: "  0712345678  ",
      email: "  JOHN@EXAMPLE.COM  ",
      kra_pin: "  p051234567a  ",
      address: "  Nairobi  ",
      notes: "  Regular customer  ",
      credit_limit: 5_000,
      payment_terms_days: 30
    )

    assert_equal "John Customer", customer.name
    assert_equal "0712345678", customer.phone
    assert_equal "john@example.com", customer.email
    assert_equal "P051234567A", customer.kra_pin
    assert_equal "Nairobi", customer.address
    assert_equal "Regular customer", customer.notes
  end

  test "kra pin must be unique within an organization" do
    organization = create_organization

    organization.customers.create!(
      name: "First Customer",
      kra_pin: "P051234567A",
      credit_limit: 0,
      payment_terms_days: 0
    )

    duplicate = organization.customers.new(
      name: "Second Customer",
      kra_pin: "p051234567a",
      credit_limit: 0,
      payment_terms_days: 0
    )

    assert_not duplicate.valid?

    assert_includes(
      duplicate.errors[:kra_pin],
      "has already been taken"
    )
  end

  test "different organizations may use the same kra pin" do
    first_organization = create_organization
    second_organization = create_organization

    first_organization.customers.create!(
      name: "First Customer",
      kra_pin: "P051234567A",
      credit_limit: 0,
      payment_terms_days: 0
    )

    customer = second_organization.customers.new(
      name: "Second Customer",
      kra_pin: "P051234567A",
      credit_limit: 0,
      payment_terms_days: 0
    )

    assert customer.valid?
  end

  test "credit limit cannot be negative" do
    customer = create_organization.customers.new(
      name: "Invalid Credit Customer",
      credit_limit: -1,
      payment_terms_days: 0
    )

    assert_not customer.valid?
    assert customer.errors[:credit_limit].any?
  end

  test "payment terms cannot be negative" do
    customer = create_organization.customers.new(
      name: "Invalid Terms Customer",
      credit_limit: 0,
      payment_terms_days: -1
    )

    assert_not customer.valid?
    assert customer.errors[:payment_terms_days].any?
  end
end
