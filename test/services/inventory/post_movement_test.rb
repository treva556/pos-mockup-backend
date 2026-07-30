require "test_helper"

module Inventory
  class PostMovementTest < ActiveSupport::TestCase
    setup do
      @owner = create_user

      @organization =
        provision_organization_for(@owner)

      @branch = @organization.main_branch

      @item = create_inventory_item(
        organization: @organization
      )
    end

    test "creates movement and updates stock level" do
      assert_difference("StockMovement.count", 1) do
        post_movement(
          movement_type: "opening",
          quantity_change: 10
        )
      end

      level =
        @organization.stock_levels.find_by!(
          branch: @branch,
          item: @item
        )

      assert_equal 10.to_d, level.quantity_on_hand
      assert_not_nil level.last_movement_at
    end

    test "outbound movement reduces available stock" do
      post_movement(
        movement_type: "opening",
        quantity_change: 10
      )

      post_movement(
        movement_type: "adjustment_out",
        quantity_change: -3
      )

      level =
        @organization.stock_levels.find_by!(
          branch: @branch,
          item: @item
        )

      assert_equal 7.to_d, level.quantity_on_hand
    end

    test "insufficient stock rolls back movement" do
      post_movement(
        movement_type: "opening",
        quantity_change: 4
      )

      assert_no_difference("StockMovement.count") do
        assert_raises(
          Inventory::InsufficientStockError
        ) do
          post_movement(
            movement_type: "adjustment_out",
            quantity_change: -5
          )
        end
      end

      level =
        @organization.stock_levels.find_by!(
          branch: @branch,
          item: @item
        )

      assert_equal 4.to_d, level.quantity_on_hand
    end

    test "opening stock can only be recorded once" do
      post_movement(
        movement_type: "opening",
        quantity_change: 10
      )

      assert_raises(
        Inventory::InvalidOpeningStockError
      ) do
        post_movement(
          movement_type: "opening",
          quantity_change: 5
        )
      end

      level =
        @organization.stock_levels.find_by!(
          branch: @branch,
          item: @item
        )

      assert_equal 10.to_d, level.quantity_on_hand

      assert_equal(
        1,
        @organization.stock_movements.where(
          branch: @branch,
          item: @item
        ).count
      )
    end

    private

    def post_movement(movement_type:, quantity_change:)
      Inventory::PostMovement.call(
        organization: @organization,
        branch: @branch,
        item: @item,
        recorded_by: @owner,
        movement_type: movement_type,
        quantity_change: quantity_change,
        occurred_at: Time.current,
        reference: "TEST-MOVEMENT"
      )
    end
  end
end
