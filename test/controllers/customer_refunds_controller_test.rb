require "test_helper"

class CustomerRefundsControllerTest <
  ActionDispatch::IntegrationTest
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
          name: "Refund Controller Item",
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
          name: "Cash Refund"
        }
      )

    @cash_account =
      create_money_account(
        organization: @organization,
        overrides: {
          name: "Refund Till"
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
            stock_disposition:
              "restock"
          }
        ]
      )

    sign_in_as(@owner)
  end

  test "owner can open refund form" do
    get new_sale_return_refund_path(
      @sale_return
    )

    assert_response :success

    assert_select "h1",
                  text: "Issue Customer Refund"

    assert_select(
      "input[name='customer_refund[amount]']"
    )

    assert_select(
      "select[name='customer_refund[payment_method_id]']"
    )

    assert_select(
      "select[name='customer_refund[money_account_id]']"
    )
  end

  test "owner can record customer refund" do
    balance_before =
      @cash_account
        .reload
        .current_balance

    assert_difference(
      "CustomerRefund.count",
      1
    ) do
      post sale_return_refunds_path(
        @sale_return
      ),
           params: {
             customer_refund: {
               amount: "200.00",
               payment_method_id:
                 @cash_method.id,
               money_account_id:
                 @cash_account.id,
               refunded_at:
                 Time.current.strftime(
                   "%Y-%m-%dT%H:%M"
                 ),
               reference:
                 "REF-TEST-001",
               notes:
                 "Controller refund test"
             }
           }
    end

    refund =
      @sale_return
        .customer_refunds
        .order(:created_at)
        .last

    assert_equal 200.to_d,
                 refund.amount

    assert_redirected_to(
      sale_return_path(
        @sale_return
      )
    )

    assert_equal(
      balance_before - 200.to_d,
      @cash_account
        .reload
        .current_balance
    )
  end

  test "refund above available amount is rejected" do
    assert_no_difference(
      "CustomerRefund.count"
    ) do
      post sale_return_refunds_path(
        @sale_return
      ),
           params: {
             customer_refund: {
               amount: "9999.00",
               payment_method_id:
                 @cash_method.id,
               money_account_id:
                 @cash_account.id,
               refunded_at:
                 Time.current.strftime(
                   "%Y-%m-%dT%H:%M"
                 )
             }
           }
    end

    assert_response :unprocessable_entity
  end

  test "cashier cannot open refund form" do
    cashier =
      create_user

    @organization
      .memberships
      .create!(
        user: cashier,
        branch: @branch,
        role: "cashier",
        active: true
      )

    delete logout_path

    sign_in_as(cashier)

    get new_sale_return_refund_path(
      @sale_return
    )

    assert_redirected_to(
      dashboard_path
    )
  end

  test "cannot access another organization's return" do
    other_owner =
      create_user

    other_organization =
      provision_organization_for(
        other_owner
      )

    other_branch =
      other_organization.main_branch

    other_customer =
      create_customer(
        organization: other_organization
      )

    other_item =
      create_inventory_item(
        organization: other_organization,
        overrides: {
          name: "Foreign Refund Item",
          selling_price: 500,
          purchase_cost: 300
        }
      )

    Inventory::PostMovement.call(
      organization: other_organization,
      branch: other_branch,
      item: other_item,
      recorded_by: other_owner,
      movement_type: "opening",
      quantity_change: 5
    )

    other_method =
      create_payment_method(
        organization: other_organization
      )

    other_account =
      create_money_account(
        organization: other_organization
      )

    foreign_sale =
      create_paid_sale_for(
        organization:
          other_organization,
        branch: other_branch,
        customer: other_customer,
        item: other_item,
        user: other_owner,
        payment_method: other_method,
        money_account: other_account
      )

    foreign_return =
      Sales::CompleteReturn.call(
        organization:
          other_organization,
        sale: foreign_sale,
        recorded_by: other_owner,
        reason_code: "other",
        lines: [
          {
            sale_line_id:
              foreign_sale
                .sale_lines
                .first
                .id,
            quantity: 1,
            stock_disposition:
              "restock"
          }
        ]
      )

    get new_sale_return_refund_path(
      foreign_return
    )

    assert_response :not_found
  end

  private

  def create_paid_sale
    create_paid_sale_for(
      organization: @organization,
      branch: @branch,
      customer: @customer,
      item: @item,
      user: @owner,
      payment_method: @cash_method,
      money_account: @cash_account
    )
  end

  def create_paid_sale_for(
    organization:,
    branch:,
    customer:,
    item:,
    user:,
    payment_method:,
    money_account:
  )
    cart =
      Sales::Cart.new(
        organization: organization,
        branch: branch
      )

    cart.customer_id =
      customer.id

    cart.add_item(
      item: item,
      quantity: 2
    )

    plan =
      Sales::PaymentPlan.new(
        organization: organization,
        branch: branch,
        sale_total:
          cart.calculation.total
      )

    plan.add_entry(
      payment_method_id:
        payment_method.id,
      money_account_id:
        money_account.id,
      amount:
        cart.calculation.total
    )

    Sales::CompleteSale.call(
      organization: organization,
      branch: branch,
      cashier: user,
      cart: cart,
      payment_plan: plan
    )
  end
end
