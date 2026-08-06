require "test_helper"

module Purchases
  class CalculateTotalsTest <
    ActiveSupport::TestCase
    setup do
      owner = create_user

      @organization =
        provision_organization_for(owner)

      @item =
        create_inventory_item(
          organization: @organization,
          overrides: {
            name: "Test Stock Item",
            purchase_cost: 500
          }
        )
    end

    test "calculates purchase totals" do
      line =
        Purchases::Cart::Line.new(
          item: @item,
          quantity: 4,
          unit_cost: 500,
          discount_amount: 200
        )

      result =
        Purchases::CalculateTotals.call(
          lines: [ line ]
        )

      assert_equal 2_000.to_d,
                   result.subtotal

      assert_equal 200.to_d,
                   result.discount_total

      assert_equal 1_800.to_d,
                   result.total

      assert_equal 1,
                   result.lines.length
    end

    test "rejects discount above gross amount" do
      line =
        Purchases::Cart::Line.new(
          item: @item,
          quantity: 1,
          unit_cost: 500,
          discount_amount: 600
        )

      assert_raises(
        Purchases::InvalidLineError
      ) do
        Purchases::CalculateTotals.call(
          lines: [ line ]
        )
      end
    end
  end
end
