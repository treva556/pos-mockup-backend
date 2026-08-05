require "test_helper"

module Purchases
  class ReceivePurchaseTest < ActiveSupport::TestCase
    setup do
      @owner = create_user

      @organization =
        provision_organization_for(@owner)

      @branch = @organization.main_branch

      @supplier =
        @organization.suppliers.create!(
          name:
            "Test Supplier #{SecureRandom.hex(4)}",
          active: true
        )

      @expiry_date =
        180.days.from_now.to_date

      @manufactured_on =
        10.days.ago.to_date

      @item =
        create_inventory_item(
          organization: @organization,
          overrides: {
            name: "Purchased Paint",
            purchase_cost: 200,
            tracks_expiry: true
          }
        )

      @opening_batch =
        @organization.inventory_batches.create!(
          branch: @branch,
          item: @item,
          batch_number: "OPENING-BATCH-001",
          manufactured_on:
            30.days.ago.to_date,
          expires_on:
            365.days.from_now.to_date,
          quantity_received: 3,
          quantity_remaining: 3,
          unit_cost: 200,
          received_at: Time.current
        )

      Inventory::PostMovement.call(
        organization: @organization,
        branch: @branch,
        item: @item,
        recorded_by: @owner,
        movement_type: "opening",
        quantity_change: 3,
        inventory_batch: @opening_batch
      )
    end

    test "receives purchase and creates expiry batch" do
      cart =
        build_cart(
          invoice_number: "SUP-INV-001",
          batch_number: "PAINT-BATCH-001",
          quantity: 5,
          unit_cost: 250
        )

      purchase = nil

      assert_difference("Purchase.count", 1) do
        assert_difference("PurchaseLine.count", 1) do
          assert_difference("InventoryBatch.count", 1) do
            assert_difference("StockMovement.count", 1) do
              purchase =
                receive_purchase(cart)
            end
          end
        end
      end

      assert purchase.received?
      assert purchase.payment_unpaid?

      assert_equal 1_250.to_d,
                   purchase.total

      assert_equal 1_250.to_d,
                   purchase.balance_due

      assert_equal "SUP-INV-001",
                   purchase.supplier_invoice_number

      level =
        @organization.stock_levels.find_by!(
          branch: @branch,
          item: @item
        )

      assert_equal 8.to_d,
                   level.quantity_on_hand

      assert_equal 250.to_d,
                   @item.reload.purchase_cost

      purchase_line =
        purchase.purchase_lines.first

      batch =
        purchase_line.inventory_batch

      assert_not_nil batch

      assert_equal "PAINT-BATCH-001",
                   batch.batch_number

      assert_equal @manufactured_on,
                   batch.manufactured_on

      assert_equal @expiry_date,
                   batch.expires_on

      assert_equal 5.to_d,
                   batch.quantity_received

      assert_equal 5.to_d,
                   batch.quantity_remaining

      assert_equal 250.to_d,
                   batch.unit_cost

      assert batch.active?
      assert batch.sellable?

      movement =
        purchase.stock_movements.first

      assert_equal purchase,
                   movement.source

      assert_equal batch,
                   movement.inventory_batch

      assert_equal 5.to_d,
                   movement.quantity_change
    end

    test "generates sequential purchase numbers" do
      first_cart =
        build_cart(
          invoice_number: "SUP-INV-001",
          batch_number: "PAINT-BATCH-001",
          quantity: 1,
          unit_cost: 250
        )

      first =
        receive_purchase(first_cart)

      second_cart =
        build_cart(
          invoice_number: "SUP-INV-002",
          batch_number: "PAINT-BATCH-002",
          quantity: 1,
          unit_cost: 260
        )

      second =
        receive_purchase(second_cart)

      assert_match(
        /-PUR-000001\z/,
        first.purchase_number
      )

      assert_match(
        /-PUR-000002\z/,
        second.purchase_number
      )

      assert_equal(
        "PAINT-BATCH-001",
        first.purchase_lines
          .first
          .inventory_batch
          .batch_number
      )

      assert_equal(
        "PAINT-BATCH-002",
        second.purchase_lines
          .first
          .inventory_batch
          .batch_number
      )
    end

    test "missing expiry date rolls back purchase" do
      cart =
        Purchases::Cart.new(
          organization: @organization,
          branch: @branch
        )

      cart.supplier_id =
        @supplier.id

      cart.supplier_invoice_number =
        "SUP-INV-NO-EXPIRY"

      cart.purchased_on =
        Date.current

      cart.add_item(
        item: @item,
        quantity: 5,
        unit_cost: 250
      )

      sequence_before =
        @branch.reload.next_purchase_sequence

      assert_no_difference("Purchase.count") do
        assert_no_difference("PurchaseLine.count") do
          assert_no_difference("InventoryBatch.count") do
            assert_no_difference("StockMovement.count") do
              assert_raises(
                Purchases::ReceivingError
              ) do
                receive_purchase(cart)
              end
            end
          end
        end
      end

      assert_equal(
        sequence_before,
        @branch.reload.next_purchase_sequence
      )

      level =
        @organization.stock_levels.find_by!(
          branch: @branch,
          item: @item
        )

      assert_equal 3.to_d,
                   level.quantity_on_hand
    end

    test "invalid purchase rolls back all records" do
      cart =
        Purchases::Cart.new(
          organization: @organization,
          branch: @branch
        )

      cart.supplier_id =
        @supplier.id

      cart.supplier_invoice_number =
        "SUP-INV-INVALID"

      cart.purchased_on =
        Date.current

      cart.add_item(
        item: @item,
        quantity: 5,
        unit_cost: -100
      )

      sequence_before =
        @branch.reload.next_purchase_sequence

      assert_no_difference("Purchase.count") do
        assert_no_difference("PurchaseLine.count") do
          assert_no_difference("InventoryBatch.count") do
            assert_no_difference("StockMovement.count") do
              assert_raises(
                Purchases::InvalidLineError
              ) do
                receive_purchase(cart)
              end
            end
          end
        end
      end

      assert_equal(
        sequence_before,
        @branch.reload.next_purchase_sequence
      )

      level =
        @organization.stock_levels.find_by!(
          branch: @branch,
          item: @item
        )

      assert_equal 3.to_d,
                   level.quantity_on_hand

      assert_equal 200.to_d,
                   @item.reload.purchase_cost
    end

    private

    def build_cart(
      invoice_number:,
      batch_number:,
      quantity:,
      unit_cost:
    )
      cart =
        Purchases::Cart.new(
          organization: @organization,
          branch: @branch
        )

      cart.supplier_id =
        @supplier.id

      cart.supplier_invoice_number =
        invoice_number

      cart.purchased_on =
        Date.current

      cart.add_item(
        item: @item,
        quantity: quantity,
        unit_cost: unit_cost
      )

      cart.update_item(
        item_id: @item.id,
        quantity: quantity,
        unit_cost: unit_cost,
        discount_amount: 0,
        batch_number: batch_number,
        manufactured_on: @manufactured_on,
        expires_on: @expiry_date
      )

      cart
    end

    def receive_purchase(cart)
      Purchases::ReceivePurchase.call(
        organization: @organization,
        branch: @branch,
        recorded_by: @owner,
        cart: cart,
        received_at: Time.current
      )
    end
  end
end
