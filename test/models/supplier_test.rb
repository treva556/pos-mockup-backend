require "test_helper"

class SupplierTest < ActiveSupport::TestCase
  test "normalizes supplier details" do
    organization = create_organization

    supplier = organization.suppliers.create!(
      name: "  Example Supplier  ",
      contact_person: "  Jane Doe  ",
      phone: "  0700000000  ",
      email: "  SALES@SUPPLIER.COM  ",
      kra_pin: "  p051234567b  ",
      address: "  Thika  ",
      notes: "  Main wholesaler  ",
      payment_terms_days: 30
    )

    assert_equal "Example Supplier", supplier.name
    assert_equal "Jane Doe", supplier.contact_person
    assert_equal "0700000000", supplier.phone
    assert_equal "sales@supplier.com", supplier.email
    assert_equal "P051234567B", supplier.kra_pin
    assert_equal "Thika", supplier.address
    assert_equal "Main wholesaler", supplier.notes
  end

  test "kra pin must be unique within an organization" do
    organization = create_organization

    organization.suppliers.create!(
      name: "First Supplier",
      kra_pin: "P051234567B",
      payment_terms_days: 0
    )

    duplicate = organization.suppliers.new(
      name: "Second Supplier",
      kra_pin: "p051234567b",
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

    first_organization.suppliers.create!(
      name: "First Supplier",
      kra_pin: "P051234567B",
      payment_terms_days: 0
    )

    supplier = second_organization.suppliers.new(
      name: "Second Supplier",
      kra_pin: "P051234567B",
      payment_terms_days: 0
    )

    assert supplier.valid?
  end

  test "payment terms cannot be negative" do
    supplier = create_organization.suppliers.new(
      name: "Invalid Supplier",
      payment_terms_days: -1
    )

    assert_not supplier.valid?
    assert supplier.errors[:payment_terms_days].any?
  end
end
