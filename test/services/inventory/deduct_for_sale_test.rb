require "test_helper"

module Inventory
  class DeductForSaleTest <
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
            name: "FEFO Juice",
            tracks_expiry: true
          }
        )

      @first_batch =
        create_batch(
          batch_number: "BATCH-A",
          expires_on:
            10.days.from_now.to_date,
          quantity: 4
        )

      @second_batch =
        create_batch(
          batch_number: "BATCH-B",
          expires_on:
            30.days.from_now.to_date,
          quantity: 10
        )
    end

    test "deducts earliest expiry batch first" do
      movements = nil

      assert_difference(
        "StockMovement.count",
        2
      ) do
        movements =
          Inventory::DeductForSale.call(
            organization: @organization,
            branch: @branch,
            item: @item,
            quantity: 12,
            recorded_by: @owner,
            reference: "SALE-001"
          )
      end

      assert_equal 2,
                   movements.length

      assert_equal 0.to_d,
                   @first_batch
                     .reload
                     .quantity_remaining

      assert @first_batch.depleted?

      assert_equal 2.to_d,
                   @second_batch
                     .reload
                     .quantity_remaining

      assert_equal(
        @first_batch,
        movements.first.inventory_batch
      )

      assert_equal(
        @second_batch,
        movements.second.inventory_batch
      )

      stock_level =
        @organization.stock_levels.find_by!(
          branch: @branch,
          item: @item
        )

      assert_equal 2.to_d,
                   stock_level.quantity_on_hand
    end

    test "expired stock cannot satisfy a sale" do
      expired_batch =
        create_batch(
          batch_number: "EXPIRED-BATCH",
          expires_on:
            2.days.ago.to_date,
          quantity: 20
        )

      assert_equal 34.to_d,
                   physical_quantity

      assert_no_difference(
        "StockMovement.count"
      ) do
        assert_raises(
          Inventory::InsufficientStockError
        ) do
          Inventory::DeductForSale.call(
            organization: @organization,
            branch: @branch,
            item: @item,
            quantity: 15,
            recorded_by: @owner
          )
        end
      end

      assert_equal 4.to_d,
                   @first_batch
                     .reload
                     .quantity_remaining

      assert_equal 10.to_d,
                   @second_batch
                     .reload
                     .quantity_remaining

      assert_equal 20.to_d,
                   expired_batch
                     .reload
                     .quantity_remaining

      assert_equal 34.to_d,
                   physical_quantity
    end

    private

    def create_batch(
      batch_number:,
      expires_on:,
      quantity:
    )
      batch =
        @organization.inventory_batches.create!(
          branch: @branch,
          item: @item,
          batch_number: batch_number,
          expires_on: expires_on,
          quantity_received: quantity,
          quantity_remaining: quantity,
          unit_cost: 100,
          received_at: Time.current
        )

      Inventory::PostMovement.call(
        organization: @organization,
        branch: @branch,
        item: @item,
        recorded_by: @owner,
        movement_type: "purchase",
        quantity_change: quantity,
        inventory_batch: batch
      )

      batch
    end

    def physical_quantity
      @organization.stock_levels.find_by!(
        branch: @branch,
        item: @item
      ).quantity_on_hand.to_d
    end
  end
end
