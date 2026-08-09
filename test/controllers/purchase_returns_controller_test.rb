require "test_helper"

class PurchaseReturnsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = create_user
    @organization = provision_organization_for(@owner)
    @branch = @organization.main_branch

    @supplier = @organization.suppliers.create!(
      name: "Return UI Supplier",
      active: true,
      payment_terms_days: 30
    )

    @item = create_inventory_item(
      organization: @organization,
      overrides: {
        name: "Return UI Item",
        purchase_cost: 250
      }
    )

    @purchase, @purchase_line = create_received_purchase(
      organization: @organization,
      branch: @branch,
      supplier: @supplier,
      item: @item,
      recorded_by: @owner,
      quantity: 4,
      unit_cost: 250
    )

    sign_in_as(@owner)
  end

  test "owner can open purchase return form" do
    get new_purchase_return_path(@purchase)

    assert_response :success
    assert_select "h1", text: "Return Items to Supplier"
    assert_select "input[name*='purchase_line_id']"
    assert_match @purchase.purchase_number, response.body
  end

  test "owner can complete purchase return" do
    assert_difference("PurchaseReturn.count", 1) do
      assert_difference("PurchaseReturnLine.count", 1) do
        post purchase_returns_path(@purchase),
             params: {
               purchase_return: {
                 reason_code: "wrong_item",
                 returned_at:
                   Time.current.strftime(
                     "%Y-%m-%dT%H:%M"
                   ),
                 supplier_document_number:
                   "SUP-RET-001",
                 reason_details:
                   "Supplier sent wrong item",
                 lines: {
                   "0" => {
                     selected: "1",
                     purchase_line_id:
                       @purchase_line.id,
                     quantity: "1"
                   }
                 }
               }
             }
      end
    end

    purchase_return =
      @organization
        .purchase_returns
        .order(:created_at)
        .last

    assert purchase_return.completed?

    assert_equal @purchase,
                 purchase_return.purchase

    assert_equal 250.to_d,
                 purchase_return.total

    assert_equal "SUP-RET-001",
                 purchase_return
                   .supplier_document_number

    assert_redirected_to(
      purchase_return_path(
        purchase_return
      )
    )

    @purchase.reload

    assert_equal 750.to_d,
                 @purchase.effective_balance_due
  end

  test "over return is rejected" do
    stock_before =
      stock_quantity(
        organization: @organization,
        branch: @branch,
        item: @item
      )

    assert_no_difference(
      "PurchaseReturn.count"
    ) do
      post purchase_returns_path(@purchase),
           params: {
             purchase_return: {
               reason_code: "other",
               returned_at:
                 Time.current.strftime(
                   "%Y-%m-%dT%H:%M"
                 ),
               lines: {
                 "0" => {
                   selected: "1",
                   purchase_line_id:
                     @purchase_line.id,
                   quantity: "99"
                 }
               }
             }
           }
    end

    assert_response :unprocessable_entity

    assert_equal(
      stock_before,
      stock_quantity(
        organization: @organization,
        branch: @branch,
        item: @item
      )
    )
  end

  test "owner can view completed return" do
    purchase_return =
      create_completed_return

    get purchase_return_path(
      purchase_return
    )

    assert_response :success

    assert_select "h1",
                  text: "Purchase Return"

    assert_match(
      purchase_return.return_number,
      response.body
    )

    assert_match(
      @purchase.purchase_number,
      response.body
    )
  end

  test "owner can view printable purchase return note" do
    purchase_return =
      create_completed_return

    get return_note_purchase_return_path(
      purchase_return
    )

    assert_response :success

    assert_match(
      "Purchase Return Note",
      response.body
    )

    assert_match(
      purchase_return.return_number,
      response.body
    )

    assert_match(
      @supplier.name,
      response.body
    )
  end

  test "cashier cannot create purchase returns" do
    cashier =
      create_user

    @organization.memberships.create!(
      user: cashier,
      branch: @branch,
      role: "cashier",
      active: true
    )

    delete logout_path

    sign_in_as(cashier)

    get new_purchase_return_path(
      @purchase
    )

    assert_redirected_to(
      dashboard_path
    )
  end

  test "cannot access another organizations purchase" do
    foreign_owner =
      create_user

    foreign_organization =
      provision_organization_for(
        foreign_owner
      )

    foreign_branch =
      foreign_organization.main_branch

    foreign_supplier =
      foreign_organization
        .suppliers
        .create!(
          name: "Foreign Supplier",
          active: true,
          payment_terms_days: 30
        )

    foreign_item =
      create_inventory_item(
        organization:
          foreign_organization,
        overrides: {
          name: "Foreign Item",
          purchase_cost: 100
        }
      )

    foreign_purchase, =
      create_received_purchase(
        organization:
          foreign_organization,
        branch:
          foreign_branch,
        supplier:
          foreign_supplier,
        item:
          foreign_item,
        recorded_by:
          foreign_owner,
        quantity: 2,
        unit_cost: 100
      )

    get new_purchase_return_path(
      foreign_purchase
    )

    assert_response :not_found
  end

  test "cannot view another organizations return" do
    foreign_owner =
      create_user

    foreign_organization =
      provision_organization_for(
        foreign_owner
      )

    foreign_branch =
      foreign_organization.main_branch

    foreign_supplier =
      foreign_organization
        .suppliers
        .create!(
          name: "Foreign Return Supplier",
          active: true,
          payment_terms_days: 30
        )

    foreign_item =
      create_inventory_item(
        organization:
          foreign_organization,
        overrides: {
          name: "Foreign Return Item",
          purchase_cost: 100
        }
      )

    foreign_purchase,
      foreign_line =
      create_received_purchase(
        organization:
          foreign_organization,
        branch:
          foreign_branch,
        supplier:
          foreign_supplier,
        item:
          foreign_item,
        recorded_by:
          foreign_owner,
        quantity: 2,
        unit_cost: 100
      )

    foreign_return =
      Purchases::CompleteReturn.call(
        organization:
          foreign_organization,
        purchase:
          foreign_purchase,
        recorded_by:
          foreign_owner,
        reason_code:
          "wrong_item",
        returned_at:
          Time.current,
        lines: [
          {
            purchase_line_id:
              foreign_line.id,
            quantity: 1
          }
        ]
      )

    get purchase_return_path(
      foreign_return
    )

    assert_response :not_found
  end

  private

  def create_completed_return
    Purchases::CompleteReturn.call(
      organization: @organization,
      purchase: @purchase,
      recorded_by: @owner,
      reason_code: "wrong_item",
      returned_at: Time.current,
      lines: [
        {
          purchase_line_id:
            @purchase_line.id,
          quantity: 1
        }
      ]
    )
  end

  def create_received_purchase(
    organization:,
    branch:,
    supplier:,
    item:,
    recorded_by:,
    quantity:,
    unit_cost:
  )
    total =
      quantity.to_d *
        unit_cost.to_d

    token =
      SecureRandom.hex(5).upcase

    purchase =
      organization.purchases.create!(
        branch: branch,
        supplier: supplier,
        recorded_by: recorded_by,
        purchase_number:
          "TEST-PUR-#{token}",
        supplier_invoice_number:
          "INV-#{token}",
        status: "received",
        payment_status: "unpaid",
        purchased_on: Date.current,
        due_on:
          30.days.from_now.to_date,
        received_at: Time.current,
        prices_include_tax: true,
        subtotal: total,
        discount_total: 0,
        tax_total: 0,
        total: total,
        amount_paid: 0,
        balance_due: total
      )

    unit =
      item.unit_of_measure

    line =
      purchase.purchase_lines.create!(
        organization: organization,
        item: item,
        line_number: 1,
        item_name: item.name,
        sku: item.sku,
        barcode: item.barcode,
        item_type:
          item.stockable? ?
            "product" :
            "service",
        unit_name: unit.name,
        unit_symbol: unit.symbol,
        quantity: quantity,
        unit_cost: unit_cost,
        gross_amount: total,
        discount_amount: 0,
        tax_percentage: 0,
        tax_amount: 0,
        line_total: total
      )

    if item.stockable?
      Inventory::PostMovement.call(
        organization: organization,
        branch: branch,
        item: item,
        recorded_by: recorded_by,
        movement_type:
          "purchase",
        quantity_change:
          quantity,
        occurred_at:
          Time.current,
        reference:
          purchase
            .supplier_invoice_number,
        source:
          purchase
      )
    end

    [
      purchase,
      line
    ]
  end

  def stock_quantity(
    organization:,
    branch:,
    item:
  )
    organization
      .stock_levels
      .find_by(
        branch: branch,
        item: item
      )
      &.quantity_on_hand
      .to_d
  end
end
