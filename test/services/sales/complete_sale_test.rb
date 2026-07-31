require "test_helper"

module Sales
  class CompleteSaleTest < ActiveSupport::TestCase
    setup do
      @owner = create_user

      @organization =
        provision_organization_for(@owner)

      @branch = @organization.main_branch

      @item =
        create_inventory_item(
          organization: @organization,
          overrides: {
            name: "White Paint",
            selling_price: 500,
            purchase_cost: 300
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

      @cash_method =
        create_payment_method(
          organization: @organization,
          overrides: {
            name: "Cash"
          }
        )

      @cash_account =
        create_money_account(
          organization: @organization,
          overrides: {
            name: "Main Cash Till"
          }
        )
    end

    test "completes a paid sale atomically" do
      cart = build_cart(quantity: 2)
      plan = build_payment_plan(cart: cart)

      plan.add_entry(
        payment_method_id: @cash_method.id,
        money_account_id: @cash_account.id,
        amount: 1_000,
        amount_tendered: 1_200
      )

      account_balance_before =
        @cash_account.current_balance

      sale = nil

      assert_difference("Sale.count", 1) do
        assert_difference("SaleLine.count", 1) do
          assert_difference("SalePayment.count", 1) do
            assert_difference("StockMovement.count", 1) do
              sale =
                complete_sale(
                  cart: cart,
                  payment_plan: plan
                )
            end
          end
        end
      end

      assert sale.completed?
      assert sale.payment_paid?

      assert_equal 1_000.to_d,
                   sale.total

      assert_equal 1_000.to_d,
                   sale.amount_paid

      assert_equal 0.to_d,
                   sale.balance_due

      assert_equal 200.to_d,
                   sale.change_given

      level =
        @organization.stock_levels.find_by!(
          branch: @branch,
          item: @item
        )

      assert_equal 8.to_d,
                   level.quantity_on_hand

      assert_equal(
        account_balance_before + 1_000.to_d,
        @cash_account.reload.current_balance
      )

      stock_movement =
        sale.stock_movements.first

      assert_equal sale,
                   stock_movement.source
    end

    test "supports split payments" do
      mpesa_method =
        create_payment_method(
          organization: @organization,
          overrides: {
            name: "M-Pesa"
          }
        )

      mpesa_account =
        create_money_account(
          organization: @organization,
          overrides: {
            name: "Main M-Pesa Till"
          }
        )

      cash_balance_before =
        @cash_account.current_balance

      mpesa_balance_before =
        mpesa_account.current_balance

      cart = build_cart(quantity: 2)
      plan = build_payment_plan(cart: cart)

      plan.add_entry(
        payment_method_id: @cash_method.id,
        money_account_id: @cash_account.id,
        amount: 400
      )

      plan.add_entry(
        payment_method_id: mpesa_method.id,
        money_account_id: mpesa_account.id,
        amount: 600,
        reference: "ABC123XYZ"
      )

      sale =
        complete_sale(
          cart: cart,
          payment_plan: plan
        )

      assert sale.payment_paid?
      assert_equal 2, sale.sale_payments.count

      assert_equal(
        [ 400.to_d, 600.to_d ],
        sale.sale_payments
          .order(:amount)
          .pluck(:amount)
      )

      assert_equal(
        cash_balance_before + 400.to_d,
        @cash_account.reload.current_balance
      )

      assert_equal(
        mpesa_balance_before + 600.to_d,
        mpesa_account.reload.current_balance
      )
    end

    test "records a named customer credit sale" do
      customer = create_test_customer

      cart =
        build_cart(
          quantity: 2,
          customer: customer
        )

      plan = build_payment_plan(cart: cart)

      sale =
        complete_sale(
          cart: cart,
          payment_plan: plan
        )

      assert sale.payment_unpaid?
      assert_equal customer, sale.customer

      assert_equal 0.to_d,
                   sale.amount_paid

      assert_equal 1_000.to_d,
                   sale.balance_due

      assert_empty sale.sale_payments
    end

    test "rejects walk-in credit sale" do
      cart = build_cart(quantity: 2)
      plan = build_payment_plan(cart: cart)

      sequence_before =
        @branch.reload.next_sale_sequence

      assert_no_difference("Sale.count") do
        assert_no_difference("StockMovement.count") do
          assert_raises(
            Sales::CompletionError
          ) do
            complete_sale(
              cart: cart,
              payment_plan: plan
            )
          end
        end
      end

      assert_equal(
        sequence_before,
        @branch.reload.next_sale_sequence
      )

      level =
        @organization.stock_levels.find_by!(
          branch: @branch,
          item: @item
        )

      assert_equal 10.to_d,
                   level.quantity_on_hand
    end

    test "insufficient stock rolls back entire sale" do
      cart = build_cart(quantity: 8)
      plan = build_payment_plan(cart: cart)

      plan.add_entry(
        payment_method_id: @cash_method.id,
        money_account_id: @cash_account.id,
        amount: 4_000
      )

      Inventory::PostMovement.call(
        organization: @organization,
        branch: @branch,
        item: @item,
        recorded_by: @owner,
        movement_type: "adjustment_out",
        quantity_change: -5,
        reference: "STOCK-COUNT"
      )

      sequence_before =
        @branch.reload.next_sale_sequence

      account_balance_before =
        @cash_account.current_balance

      assert_no_difference("Sale.count") do
        assert_no_difference("SaleLine.count") do
          assert_no_difference("SalePayment.count") do
            assert_raises(
              Inventory::InsufficientStockError
            ) do
              complete_sale(
                cart: cart,
                payment_plan: plan
              )
            end
          end
        end
      end

      assert_equal(
        sequence_before,
        @branch.reload.next_sale_sequence
      )

      level =
        @organization.stock_levels.find_by!(
          branch: @branch,
          item: @item
        )

      assert_equal 5.to_d,
                   level.quantity_on_hand

      assert_equal(
        account_balance_before,
        @cash_account.reload.current_balance
      )
    end

    private

    def create_test_customer
      @organization.customers.create!(
        name:
          "Credit Customer #{SecureRandom.hex(4)}",
        active: true
      )
    end

    def build_cart(quantity:, customer: nil)
      cart =
        Sales::Cart.new(
          organization: @organization,
          branch: @branch
        )

      cart.customer_id =
        customer.id if customer

      cart.add_item(
        item: @item,
        quantity: quantity
      )

      cart
    end

    def build_payment_plan(cart:)
      Sales::PaymentPlan.new(
        organization: @organization,
        branch: @branch,
        sale_total: cart.calculation.total
      )
    end

    def complete_sale(cart:, payment_plan:)
      Sales::CompleteSale.call(
        organization: @organization,
        branch: @branch,
        cashier: @owner,
        cart: cart,
        payment_plan: payment_plan,
        sold_at: Time.current
      )
    end
  end
end
