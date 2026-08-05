require "test_helper"

module Sales
  class CartTest < ActiveSupport::TestCase
    setup do
      @owner = create_user

      @organization =
        provision_organization_for(@owner)

      @branch = @organization.main_branch

      @item =
        create_inventory_item(
          organization: @organization,
          overrides: {
            selling_price: 500
          }
        )

      Inventory::PostMovement.call(
        organization: @organization,
        branch: @branch,
        item: @item,
        recorded_by: @owner,
        movement_type: "opening",
        quantity_change: 10
      )

      @cart =
        Sales::Cart.new(
          organization: @organization,
          branch: @branch
        )
    end

    test "adds an item and calculates totals" do
      @cart.add_item(
        item: @item,
        quantity: 2
      )

      assert_equal 1, @cart.item_count
      assert_equal 1_000.to_d,
                   @cart.calculation.total
    end

    test "adding same item increases its quantity" do
      @cart.add_item(
        item: @item,
        quantity: 2
      )

      @cart.add_item(
        item: @item,
        quantity: 3
      )

      assert_equal 5.to_d,
                   @cart.lines.first.quantity
    end

    test "rejects quantity above available stock" do
      error =
        assert_raises(
          Sales::InvalidLineError
        ) do
          @cart.add_item(
            item: @item,
            quantity: 11
          )
        end

      assert_match(
        "only has 10",
        error.message
      )

      assert @cart.empty?
    end

    test "restores cart after invalid update" do
      @cart.add_item(
        item: @item,
        quantity: 2
      )

      assert_raises(
        Sales::InvalidLineError
      ) do
        @cart.update_item(
          item_id: @item.id,
          quantity: 20,
          discount_amount: 0
        )
      end

      assert_equal 2.to_d,
                   @cart.lines.first.quantity
    end

    test "round trips through session data" do
      @cart.add_item(
        item: @item,
        quantity: 3
      )

      restored =
        Sales::Cart.new(
          organization: @organization,
          branch: @branch,
          data: @cart.to_session
        )

      assert_equal 3.to_d,
                   restored.lines.first.quantity

      assert_equal 1_500.to_d,
                   restored.calculation.total
    end
  end
end
