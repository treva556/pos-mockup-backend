require "test_helper"

module Sales
  class CalculateTotalsTest < ActiveSupport::TestCase
    FakeTaxRate =
      Struct.new(:rate)

    setup do
      @organization =
        provision_organization_for(create_user)

      @item =
        create_inventory_item(
          organization: @organization,
          overrides: {
            name: "White Paint",
            selling_price: 1_000,
            purchase_cost: 600
          }
        )
    end
        test "calculates inclusive tax and discount totals" do
        tax_rate =
            FakeTaxRate.new(16.to_d)

        @item.define_singleton_method(:tax_rate) do
            tax_rate
        end

        result =
            Sales::CalculateTotals.call(
            lines: [
                {
                item: @item,
                quantity: 2,
                discount_amount: 200
                }
            ]
            )

        line = result.lines.first

        assert_equal 2_000.to_d,
                    line[:gross_amount]

        assert_equal 200.to_d,
                    line[:discount_amount]

        assert_equal 1_800.to_d,
                    line[:line_total]

        assert_equal 16.to_d,
                    line[:tax_rate_percentage]

        assert_equal 248.28.to_d,
                    line[:tax_amount]

        assert_equal 2_000.to_d,
                    result.subtotal

        assert_equal 200.to_d,
                    result.discount_total

        assert_equal 248.28.to_d,
                    result.tax_total

        assert_equal 1_800.to_d,
                    result.total
        end
     

    test "uses item selling price by default" do
      result =
        Sales::CalculateTotals.call(
          lines: [
            {
              item: @item,
              quantity: 3
            }
          ]
        )

      line = result.lines.first

      assert_equal 1_000.to_d,
                   line[:unit_price]

      assert_equal 3_000.to_d,
                   result.total
    end

    test "rejects an empty sale" do
      error =
        assert_raises(
          Sales::InvalidLineError
        ) do
          Sales::CalculateTotals.call(
            lines: []
          )
        end

      assert_equal(
        "A sale must contain at least one item",
        error.message
      )
    end

    test "rejects zero quantity" do
      assert_raises(
        Sales::InvalidLineError
      ) do
        Sales::CalculateTotals.call(
          lines: [
            {
              item: @item,
              quantity: 0
            }
          ]
        )
      end
    end

    test "rejects decimal quantity for whole units" do
      assert_raises(
        Sales::InvalidLineError
      ) do
        Sales::CalculateTotals.call(
          lines: [
            {
              item: @item,
              quantity: 1.5
            }
          ]
        )
      end
    end

    test "rejects discount above gross amount" do
      assert_raises(
        Sales::InvalidLineError
      ) do
        Sales::CalculateTotals.call(
          lines: [
            {
              item: @item,
              quantity: 1,
              discount_amount: 1_100
            }
          ]
        )
      end
    end
  end
end