require "test_helper"

class SaleReturnsControllerTest <
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
          name: "Controller Return Item",
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

    @sale =
      create_paid_sale(
        organization: @organization,
        branch: @branch,
        customer: @customer,
        item: @item,
        user: @owner,
        payment_method: @cash_method,
        money_account: @cash_account
      )

    sign_in_as(@owner)
  end

  test "owner can open sales return form" do
    get new_sale_return_path(@sale)

    assert_response :success

    assert_select "h1",
                  text: "Return Sale Items"

    assert_select "form"

    assert_select(
      "input[name*='sale_line_id']"
    )
  end

  test "owner can complete a sales return" do
    source_line =
      @sale.sale_lines.first

    assert_difference(
      "SaleReturn.count",
      1
    ) do
      assert_difference(
        "SaleReturnLine.count",
        1
      ) do
        post sale_returns_path(@sale),
             params: {
               sale_return: {
                 reason_code: "other",
                 reason_details:
                   "Customer returned the item",
                 returned_at:
                   Time.current.strftime(
                     "%Y-%m-%dT%H:%M"
                   ),
                 lines: {
                   "0" => {
                     selected: "1",
                     sale_line_id:
                       source_line.id,
                     quantity: "1",
                     stock_disposition:
                       "restock"
                   }
                 }
               }
             }
      end
    end

    sale_return =
      @organization
        .sale_returns
        .order(:created_at)
        .last

    assert sale_return.completed?

    assert_redirected_to(
      sale_return_path(sale_return)
    )

    assert_equal @sale,
                 sale_return.sale

    assert_equal 500.to_d,
                 sale_return.total
  end

  test "return form rejects an over return" do
    source_line =
      @sale.sale_lines.first

    original_stock =
      stock_quantity(
        organization: @organization,
        branch: @branch,
        item: @item
      )

    assert_no_difference(
      "SaleReturn.count"
    ) do
      post sale_returns_path(@sale),
           params: {
             sale_return: {
               reason_code: "other",
               returned_at:
                 Time.current.strftime(
                   "%Y-%m-%dT%H:%M"
                 ),
               lines: {
                 "0" => {
                   selected: "1",
                   sale_line_id:
                     source_line.id,
                   quantity: "99",
                   stock_disposition:
                     "restock"
                 }
               }
             }
           }
    end

    assert_response :unprocessable_entity

    assert_equal(
      original_stock,
      stock_quantity(
        organization: @organization,
        branch: @branch,
        item: @item
      )
    )
  end

  test "owner can view a completed sales return" do
    sale_return =
      create_completed_return

    get sale_return_path(sale_return)

    assert_response :success

    assert_select "h1",
                  text: "Sales Return"

    assert_match(
      sale_return.return_number,
      response.body
    )

    assert_match(
      @sale.sale_number,
      response.body
    )
  end

  test "owner can view printable return note" do
    sale_return =
      create_completed_return

    get return_note_sale_return_path(
      sale_return
    )

    assert_response :success

    assert_match(
      "SALES RETURN NOTE",
      response.body
    )

    assert_match(
      sale_return.return_number,
      response.body
    )
  end

  test "cannot access a sale from another organization" do
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
          name: "Foreign Item",
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
      create_paid_sale(
        organization:
          other_organization,
        branch: other_branch,
        customer: other_customer,
        item: other_item,
        user: other_owner,
        payment_method: other_method,
        money_account: other_account
      )

    get new_sale_return_path(
      foreign_sale
    )

    assert_response :not_found
  end

  test "cannot view another organization's return" do
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
          name: "Foreign Return Item",
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
      create_paid_sale(
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

    get sale_return_path(
      foreign_return
    )

    assert_response :not_found
  end

  private

  def create_completed_return
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
  end

  def create_paid_sale(
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

  def stock_quantity(
    organization:,
    branch:,
    item:
  )
    organization
      .stock_levels
      .find_by!(
        branch: branch,
        item: item
      )
      .quantity_on_hand
      .to_d
  end
end
