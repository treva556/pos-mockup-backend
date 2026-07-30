require "test_helper"

class StockLevelTest < ActiveSupport::TestCase
  setup do
    @organization =
      provision_organization_for(create_user)

    @branch = @organization.main_branch

    @item = create_inventory_item(
      organization: @organization
    )
  end

  test "identifies low and out of stock levels" do
    level = create_stock_level(
      organization: @organization,
      branch: @branch,
      item: @item,
      overrides: {
        quantity_on_hand: 1,
        reorder_level: 3
      }
    )

    assert level.low_stock?
    assert_not level.out_of_stock?

    level.update!(quantity_on_hand: 0)

    assert_not level.low_stock?
    assert level.out_of_stock?
  end

  test "rejects a service item" do
    service = create_inventory_item(
      organization: @organization,
      overrides: {
        name: "Bookkeeping Service",
        item_type: "service",
        track_inventory: false
      }
    )

    level = @organization.stock_levels.new(
      branch: @branch,
      item: service,
      quantity_on_hand: 0,
      reorder_level: 0
    )

    assert_not level.valid?

    assert_includes(
      level.errors[:item],
      "must be an inventory-tracked product"
    )
  end

  test "rejects branch from another organization" do
    other_organization =
      provision_organization_for(create_user)

    level = @organization.stock_levels.new(
      branch: other_organization.main_branch,
      item: @item,
      quantity_on_hand: 0,
      reorder_level: 0
    )

    assert_not level.valid?

    assert_includes(
      level.errors[:branch],
      "must belong to the same organization"
    )
  end

  test "whole-number unit rejects decimal quantities" do
    level = @organization.stock_levels.new(
      branch: @branch,
      item: @item,
      quantity_on_hand: 1.5,
      reorder_level: 0
    )

    assert_not level.valid?

    assert_includes(
      level.errors[:quantity_on_hand],
      "must be a whole number for this unit"
    )
  end

  test "decimal-enabled unit accepts decimal quantities" do
    decimal_unit = create_unit_of_measure(
      organization: @organization,
      overrides: {
        name: "Kilogram",
        symbol: "kg",
        decimal_allowed: true
      }
    )

    item = create_inventory_item(
      organization: @organization,
      overrides: {
        name: "Loose Sugar",
        unit_of_measure: decimal_unit
      }
    )

    level = @organization.stock_levels.new(
      branch: @branch,
      item: item,
      quantity_on_hand: 1.5,
      reorder_level: 0.5
    )

    assert level.valid?
  end
end
