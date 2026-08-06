require "test_helper"

module Inventory
  class AssignExistingStockBatchTest <
    ActiveSupport::TestCase
    setup do
      @owner = create_user

      @organization =
        provision_organization_for(@owner)

      @branch =
        @organization.main_branch

      @item =
        create_inventory_item(
          organization: @organization,
          overrides: {
            name: "Existing Milk",
            purchase_cost: 90,
            tracks_expiry: false
          }
        )

      Inventory::PostMovement.call(
        organization: @organization,
        branch: @branch,
        item: @item,
        recorded_by: @owner,
        movement_type: "opening",
        quantity_change: 12
      )

      @item.update!(
        tracks_expiry: true
      )
    end

    test "assigns existing stock without increasing stock" do
      stock_before =
        stock_level.quantity_on_hand

      movement_count =
        StockMovement.count

      batch = nil

      assert_difference(
        "InventoryBatch.count",
        1
      ) do
        batch =
          Inventory::AssignExistingStockBatch.call(
            organization: @organization,
            branch: @branch,
            item: @item,
            batch_number: "MILK-OPEN-001",
            expires_on:
              30.days.from_now.to_date,
            unit_cost: 90
          )
      end

      assert_equal movement_count,
                   StockMovement.count

      assert_equal stock_before,
                   stock_level.reload.quantity_on_hand

      assert_equal 12.to_d,
                   batch.quantity_received

      assert_equal 12.to_d,
                   batch.quantity_remaining

      assert_equal 12.to_d,
                   stock_level.sellable_quantity

      assert_equal 0.to_d,
                   stock_level.unassigned_expiry_quantity
    end

    test "rejects a second assignment when all stock is assigned" do
      Inventory::AssignExistingStockBatch.call(
        organization: @organization,
        branch: @branch,
        item: @item,
        batch_number: "MILK-OPEN-001",
        expires_on:
          30.days.from_now.to_date
      )

      assert_no_difference(
        "InventoryBatch.count"
      ) do
        assert_raises(
          Inventory::BatchAssignmentError
        ) do
          Inventory::AssignExistingStockBatch.call(
            organization: @organization,
            branch: @branch,
            item: @item,
            batch_number: "MILK-OPEN-002",
            expires_on:
              60.days.from_now.to_date
          )
        end
      end
    end

    private

    def stock_level
      @stock_level ||=
        @organization.stock_levels.find_by!(
          branch: @branch,
          item: @item
        )
    end
  end
end
