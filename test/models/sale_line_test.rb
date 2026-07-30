require "test_helper"

class SaleLineTest < ActiveSupport::TestCase
  setup do
    @owner = create_user

    @organization =
      provision_organization_for(@owner)

    @branch = @organization.main_branch

    @item =
      create_inventory_item(
        organization: @organization
      )

    @sale =
      @organization.sales.create!(
        branch: @branch,
        cashier: @owner,
        sale_number: "TEST-000001",
        status: "draft",
        payment_status: "unpaid",
        subtotal: 0,
        discount_total: 0,
        tax_total: 0,
        total: 0,
        amount_paid: 0,
        balance_due: 0,
        change_given: 0
      )
  end

  test "accepts a valid sale line snapshot" do
    line = build_line

    assert line.valid?
  end

  test "rejects an item from another organization" do
    other_organization =
      provision_organization_for(create_user)

    foreign_item =
      create_inventory_item(
        organization: other_organization
      )

    line = build_line(
      item: foreign_item
    )

    assert_not line.valid?

    assert_includes(
      line.errors[:item],
      "must belong to the same organization"
    )
  end

  test "rejects decimal quantity for whole unit" do
    line = build_line(
      quantity: 1.5,
      gross_amount: 150,
      line_total: 150
    )

    assert_not line.valid?

    assert_includes(
      line.errors[:quantity],
      "must be a whole number for this unit"
    )
  end

  test "rejects discount above gross amount" do
    line = build_line(
      gross_amount: 100,
      discount_amount: 120,
      line_total: 0
    )

    assert_not line.valid?

    assert_includes(
      line.errors[:discount_amount],
      "cannot exceed the gross amount"
    )
  end

  private

  def build_line(overrides = {})
    unit = @item.unit_of_measure

    defaults = {
      sale: @sale,
      item: @item,
      tax_rate: nil,
      line_number: 1,
      item_name: @item.name,
      sku: @item.sku,
      barcode: @item.barcode,
      item_type: @item.item_type,
      unit_name: unit.name,
      unit_symbol: unit.symbol,
      quantity: 1,
      unit_price: 100,
      unit_cost: 60,
      gross_amount: 100,
      discount_amount: 0,
      tax_rate_percentage: 0,
      tax_amount: 0,
      line_total: 100
    }

    @organization.sale_lines.new(
      defaults.merge(overrides)
    )
  end
end