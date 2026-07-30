require "test_helper"

class SaleTest < ActiveSupport::TestCase
  setup do
    @owner = create_user

    @organization =
      provision_organization_for(@owner)

    @branch = @organization.main_branch
  end

  test "allows a walk-in draft sale" do
    sale = build_sale

    assert sale.valid?
    assert sale.walk_in?
    assert sale.editable?
  end

  test "completed sale requires sold at" do
    sale = build_sale(
      status: "completed",
      sold_at: nil
    )

    assert_not sale.valid?

    assert_includes(
      sale.errors[:sold_at],
      "must be present for a completed sale"
    )
  end

  test "rejects branch from another organization" do
    other_organization =
      provision_organization_for(create_user)

    sale = build_sale(
      branch: other_organization.main_branch
    )

    assert_not sale.valid?

    assert_includes(
      sale.errors[:branch],
      "must belong to the same organization"
    )
  end

  test "balance must equal total minus amount paid" do
    sale = build_sale(
      total: 1_000,
      amount_paid: 400,
      balance_due: 500
    )

    assert_not sale.valid?

    assert_includes(
      sale.errors[:balance_due],
      "must equal the total minus the amount paid"
    )
  end

  private

  def build_sale(overrides = {})
    defaults = {
      branch: @branch,
      cashier: @owner,
      sale_number: "TEST-000001",
      status: "draft",
      payment_status: "unpaid",
      prices_include_tax: true,
      subtotal: 1_000,
      discount_total: 0,
      tax_total: 0,
      total: 1_000,
      amount_paid: 0,
      balance_due: 1_000,
      change_given: 0
    }

    @organization.sales.new(
      defaults.merge(overrides)
    )
  end
end
