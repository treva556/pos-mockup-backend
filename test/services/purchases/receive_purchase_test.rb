require "test_helper"

module Purchases
  class ReceivePurchaseTest <
    ActiveSupport::TestCase
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

      @item =
        create_inventory_item(
          organization: @organization,
          overrides: {
            name: "Purchased Paint",
            purchase_cost: 200
          }
        )

      Inventory::PostMovement.call(
        organization: @organization,
        branch: @branch,
        item: @item,
        recorded_by: @owner,
        movement_type: "opening",
        quantity_change: 3
      )
    end

    test "receives purchase and increases stock" do
      cart = build_cart

      cart.add_item(
        item: @item,
        quantity: 5,
        unit_cost: 250
      )

      purchase = nil

      assert_difference("Purchase.count", 1) do
        assert_difference("PurchaseLine.count", 1) do
          assert_difference("StockMovement.count", 1) do
            purchase =
              receive_purchase(cart)
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

      movement =
        purchase.stock_movements.first

      assert_equal purchase,
                   movement.source
    end

    test "generates sequential purchase numbers" do
      first_cart = build_cart

      first_cart.add_item(
        item: @item,
        quantity: 1,
        unit_cost: 250
      )

      first =
        receive_purchase(first_cart)

      second_cart =
        Purchases::Cart.new(
          organization: @organization,
          branch: @branch
        )

      second_cart.supplier_id =
        @supplier.id

      second_cart.supplier_invoice_number =
        "SUP-INV-002"

      second_cart.purchased_on =
        Date.current

      second_cart.add_item(
        item: @item,
        quantity: 1,
        unit_cost: 250
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
    end

    test "failed purchase does not alter stock" do
      cart = build_cart

      cart.add_item(
        item: @item,
        quantity: 5,
        unit_cost: -100
      )

      sequence_before =
        @branch.reload.next_purchase_sequence

      assert_no_difference("Purchase.count") do
        assert_no_difference("StockMovement.count") do
          assert_raises(
            Purchases::InvalidLineError
          ) do
            receive_purchase(cart)
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

    private

    def build_cart
      cart =
        Purchases::Cart.new(
          organization: @organization,
          branch: @branch
        )

      cart.supplier_id =
        @supplier.id

      cart.supplier_invoice_number =
        "SUP-INV-001"

      cart.purchased_on =
        Date.current

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
