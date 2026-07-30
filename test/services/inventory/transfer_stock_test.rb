require "test_helper"

module Inventory
  class TransferStockTest < ActiveSupport::TestCase
    setup do
      @owner = create_user

      @organization =
        provision_organization_for(@owner)

      @from_branch = @organization.main_branch

      @to_branch =
        create_branch(organization: @organization)

      @item = create_inventory_item(
        organization: @organization
      )

      Inventory::PostMovement.call(
        organization: @organization,
        branch: @from_branch,
        item: @item,
        recorded_by: @owner,
        movement_type: "opening",
        quantity_change: 20
      )
    end

    test "creates paired movements and updates both branches" do
      assert_difference("StockTransfer.count", 1) do
        assert_difference("StockMovement.count", 2) do
          Inventory::TransferStock.call(
            organization: @organization,
            from_branch: @from_branch,
            to_branch: @to_branch,
            item: @item,
            recorded_by: @owner,
            quantity: 7,
            reference: "TRANSFER-001"
          )
        end
      end

      source_level =
        @organization.stock_levels.find_by!(
          branch: @from_branch,
          item: @item
        )

      destination_level =
        @organization.stock_levels.find_by!(
          branch: @to_branch,
          item: @item
        )

      assert_equal 13.to_d,
                   source_level.quantity_on_hand

      assert_equal 7.to_d,
                   destination_level.quantity_on_hand

      transfer =
        @organization.stock_transfers.last

      assert_equal(
        %w[transfer_out transfer_in],
        transfer.stock_movements.order(:id).pluck(
          :movement_type
        )
      )
    end

    test "insufficient stock rolls back entire transfer" do
      assert_no_difference("StockTransfer.count") do
        assert_no_difference("StockMovement.count") do
          assert_raises(
            Inventory::InsufficientStockError
          ) do
            Inventory::TransferStock.call(
              organization: @organization,
              from_branch: @from_branch,
              to_branch: @to_branch,
              item: @item,
              recorded_by: @owner,
              quantity: 25
            )
          end
        end
      end

      source_level =
        @organization.stock_levels.find_by!(
          branch: @from_branch,
          item: @item
        )

      assert_equal 20.to_d,
                   source_level.quantity_on_hand

      assert_nil(
        @organization.stock_levels.find_by(
          branch: @to_branch,
          item: @item
        )
      )
    end
  end
end
