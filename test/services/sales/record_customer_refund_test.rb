require "test_helper"

module Sales
  class RecordCustomerRefundTest <
    ActiveSupport::TestCase
    setup do
      @owner = create_user

      @organization =
        provision_organization_for(@owner)

      @branch =
        @organization.main_branch

      @customer =
        create_customer(
          organization: @organization
        )

      @item =
        create_inventory_item(
          organization: @organization,
          overrides: {
            name: "Refundable Item",
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
            name: "Refund Cash Till"
          }
        )

      @sale =
        create_paid_sale

      @sale_return =
        Sales::CompleteReturn.call(
          organization: @organization,
          sale: @sale,
          recorded_by: @owner,
          reason_code: "other",
          lines: [
            {
              sale_line_id:
                @sale.sale_lines.first.id,
              quantity: 1,
              stock_disposition: "restock"
            }
          ]
        )
    end

    test "records a partial refund and reduces money account balance" do
      balance_before =
        @cash_account
          .reload
          .current_balance

      refund = nil

      assert_difference(
        "CustomerRefund.count",
        1
      ) do
        refund =
          record_refund(
            amount: 300
          )
      end

      assert_equal 300.to_d,
                   refund.amount

      assert_equal @sale_return,
                   refund.sale_return

      assert_equal @cash_account,
                   refund.money_account

      assert_equal(
        balance_before - 300.to_d,
        @cash_account
          .reload
          .current_balance
      )

      assert_equal 200.to_d,
                   @sale.reload.available_return_refund

      assert_equal 200.to_d,
                   @sale_return.reload.refundable_balance

      refute @sale_return.refunded?
    end

    test "supports multiple refunds up to the refundable total" do
      record_refund(
        amount: 300
      )

      record_refund(
        amount: 200
      )

      assert_equal 500.to_d,
                   @sale_return.reload.refund_total

      assert_equal 0.to_d,
                   @sale.available_return_refund

      assert_equal 0.to_d,
                   @sale_return.refundable_balance

      assert @sale_return.refunded?
    end

    test "rejects a refund above the refundable balance" do
      balance_before =
        @cash_account
          .reload
          .current_balance

      assert_no_difference(
        "CustomerRefund.count"
      ) do
        assert_raises(
          Sales::RefundError
        ) do
          record_refund(
            amount: 501
          )
        end
      end

      assert_equal(
        balance_before,
        @cash_account
          .reload
          .current_balance
      )

      assert_equal 500.to_d,
                   @sale.reload.available_return_refund
    end

    test "rejects a refund when the money account lacks funds" do
      low_balance_account =
        create_money_account(
          organization: @organization,
          overrides: {
            name: "Small Refund Till",
            opening_balance: 100,
            can_pay: true
          }
        )

      assert_equal 100.to_d,
                   low_balance_account.current_balance

      assert_no_difference(
        "CustomerRefund.count"
      ) do
        assert_raises(
          Sales::RefundError
        ) do
          record_refund(
            amount: 200,
            money_account:
              low_balance_account
          )
        end
      end

      assert_equal 100.to_d,
                   low_balance_account
                     .reload
                     .current_balance
    end

    test "cashier can process a return but cannot issue a refund" do
      cashier =
        create_user

      @organization.memberships.create!(
        user: cashier,
        branch: @branch,
        role: "cashier",
        active: true
      )

      second_sale =
        create_paid_sale

      cashier_return =
        Sales::CompleteReturn.call(
          organization: @organization,
          sale: second_sale,
          recorded_by: cashier,
          reason_code: "other",
          lines: [
            {
              sale_line_id:
                second_sale.sale_lines.first.id,
              quantity: 1,
              stock_disposition: "restock"
            }
          ]
        )

      assert cashier_return.completed?

      assert_no_difference(
        "CustomerRefund.count"
      ) do
        assert_raises(
          Sales::RefundError
        ) do
          Sales::RecordCustomerRefund.call(
            organization: @organization,
            sale_return: cashier_return,
            recorded_by: cashier,
            payment_method: @cash_method,
            money_account: @cash_account,
            amount: 100
          )
        end
      end
    end

    private

    def create_paid_sale
      cart =
        Sales::Cart.new(
          organization: @organization,
          branch: @branch
        )

      cart.customer_id =
        @customer.id

      cart.add_item(
        item: @item,
        quantity: 2
      )

      plan =
        Sales::PaymentPlan.new(
          organization: @organization,
          branch: @branch,
          sale_total:
            cart.calculation.total
        )

      plan.add_entry(
        payment_method_id:
          @cash_method.id,
        money_account_id:
          @cash_account.id,
        amount:
          cart.calculation.total
      )

      Sales::CompleteSale.call(
        organization: @organization,
        branch: @branch,
        cashier: @owner,
        cart: cart,
        payment_plan: plan
      )
    end

    def record_refund(
      amount:,
      money_account: @cash_account
    )
      Sales::RecordCustomerRefund.call(
        organization: @organization,
        sale_return: @sale_return,
        recorded_by: @owner,
        payment_method: @cash_method,
        money_account: money_account,
        amount: amount,
        refunded_at: Time.current
      )
    end
  end
end
