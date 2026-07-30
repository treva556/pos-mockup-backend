require "test_helper"

class StockMovementTest < ActiveSupport::TestCase
  setup do
    @owner = create_user

    @organization =
      provision_organization_for(@owner)

    @branch = @organization.main_branch

    @item = create_inventory_item(
      organization: @organization
    )
  end

  test "accepts correct movement direction" do
    inbound = build_movement(
      movement_type: "adjustment_in",
      quantity_change: 5
    )

    outbound = build_movement(
      movement_type: "adjustment_out",
      quantity_change: -2
    )

    assert inbound.valid?
    assert outbound.valid?
    assert inbound.inbound?
    assert outbound.outbound?
  end

  test "rejects movement with incorrect direction" do
    movement = build_movement(
      movement_type: "sale",
      quantity_change: 2
    )

    assert_not movement.valid?

    assert_includes(
      movement.errors[:quantity_change],
      "has the wrong direction for this movement type"
    )
  end

  test "whole-number unit rejects decimal movement" do
    movement = build_movement(
      movement_type: "adjustment_in",
      quantity_change: 1.5
    )

    assert_not movement.valid?

    assert_includes(
      movement.errors[:quantity_change],
      "must be a whole number for this unit"
    )
  end

  test "rejects item from another organization" do
    other_organization =
      provision_organization_for(create_user)

    foreign_item = create_inventory_item(
      organization: other_organization
    )

    movement = build_movement(
      item: foreign_item,
      movement_type: "adjustment_in",
      quantity_change: 1
    )

    assert_not movement.valid?

    assert_includes(
      movement.errors[:item],
      "must belong to the same organization"
    )
  end

  private

  def build_movement(
    item: @item,
    movement_type:,
    quantity_change:
  )
    @organization.stock_movements.new(
      branch: @branch,
      item: item,
      recorded_by: @owner,
      movement_type: movement_type,
      quantity_change: quantity_change,
      occurred_at: Time.current
    )
  end
end
