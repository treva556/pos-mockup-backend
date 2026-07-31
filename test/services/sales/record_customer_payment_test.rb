require "test_helper"

module Sales
  class RecordCustomerPaymentTest <
    ActiveSupport::TestCase
    setup do
      @owner = create_user

      @organization =
        provision_organization_for(@owner)

      @branch = @organization.main_branch

      @customer =
        @organization.customers.create!(
          name:
            "Credit Customer #{SecureRandom.hex(4)}",
          active: true
        )

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

      cart =
        Sales::Cart.new(
          organization: @organization,
          branch: @branch
        )

      cart.customer_id = @customer.id

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

      @sale =
        Sales::CompleteSale.call(
          organization: @organization,
          branch: @branch,
          cashier: @owner,
          cart: cart,
          payment_plan: plan,
          due_on:
            30.days.from_now.to_date
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

    test "records a partial customer payment" do
      balance_before =
        @cash_account.current_balance

      payment =
        record_payment(
          amount: 400,
          amount_tendered: 500
        )

      assert_equal 100.to_d,
                   payment.change_given

      @sale.reload

      assert_equal 400.to_d,
                   @sale.amount_paid

      assert_equal 600.to_d,
                   @sale.balance_due

      assert @sale.payment_partially_paid?

      assert_equal(
        balance_before + 400.to_d,
        @cash_account.reload.current_balance
      )
    end

    test "final payment marks sale as paid" do
      record_payment(amount: 400)
      record_payment(amount: 600)

      @sale.reload

      assert_equal 1_000.to_d,
                   @sale.amount_paid

      assert_equal 0.to_d,
                   @sale.balance_due

      assert @sale.payment_paid?
    end

    test "rejects payment above outstanding balance" do
      balance_before =
        @cash_account.current_balance

      assert_no_difference("SalePayment.count") do
        assert_raises(
          Sales::InvalidCustomerPaymentError
        ) do
          record_payment(amount: 1_100)
        end
      end

      @sale.reload

      assert_equal 0.to_d,
                   @sale.amount_paid

      assert_equal 1_000.to_d,
                   @sale.balance_due

      assert_equal(
        balance_before,
        @cash_account.reload.current_balance
      )
    end

    private

    def record_payment(
      amount:,
      amount_tendered: nil
    )
      Sales::RecordCustomerPayment.call(
        organization: @organization,
        sale: @sale,
        recorded_by: @owner,
        payment_method: @cash_method,
        money_account: @cash_account,
        amount: amount,
        amount_tendered:
          amount_tendered || amount,
        paid_at: Time.current
      )
    end
  end
end
