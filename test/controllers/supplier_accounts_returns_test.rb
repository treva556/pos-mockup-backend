require "test_helper"

class SupplierAccountsReturnsTest <
  ActionDispatch::IntegrationTest
  setup do
    @owner = create_user
    @organization =
      provision_organization_for(@owner)

    @branch =
      @organization.main_branch

    @supplier =
      @organization.suppliers.create!(
        name: "Supplier Account Returns Test",
        active: true,
        payment_terms_days: 30
      )

    @item =
      create_inventory_item(
        organization: @organization,
        overrides: {
          name: "Supplier Statement Item",
          purchase_cost: 250
        }
      )

    @payment_method =
      create_payment_method(
        organization: @organization,
        overrides: {
          name: "Supplier Account Bank"
        }
      )

    @money_account =
      create_money_account(
        organization: @organization,
        overrides: {
          name: "Supplier Account Test Bank",
          account_type: "bank",
          opening_balance: 20_000,
          opening_balance_date: Date.current,
          can_pay: true,
          can_receive: true
        }
      )

    @purchase,
      @purchase_line =
      create_received_purchase

    Purchases::RecordSupplierPayment.call(
      organization: @organization,
      purchase: @purchase,
      payment_method: @payment_method,
      money_account: @money_account,
      recorded_by: @owner,
      amount: 800,
      paid_at: Time.current
    )

    @purchase_return =
      Purchases::CompleteReturn.call(
        organization: @organization,
        purchase: @purchase,
        recorded_by: @owner,
        reason_code: "quality_issue",
        returned_at: Time.current,
        lines: [
          {
            purchase_line_id:
              @purchase_line.id,
            quantity: 2
          }
        ]
      )

    @supplier_credit =
      Purchases::RecordSupplierCredit.call(
        organization: @organization,
        purchase_return: @purchase_return,
        recorded_by: @owner,
        amount: 300,
        credit_number: "CN-ACCOUNT-001",
        issued_on: Date.current
      )

    sign_in_as(@owner)
  end

  test "supplier account includes returns and available credit" do
    get supplier_account_path(
      @supplier
    )

    assert_response :success

    assert_select "h1",
                  text:
                    "#{@supplier.name} Account"

    assert_select "dt",
                  text: "Total purchases"

    assert_select "dt",
                  text: "Total paid"

    assert_select "dt",
                  text: "Total returns"

    assert_select "dt",
                  text: "Outstanding payable"

    assert_select "dt",
                  text: "Available supplier credit"

    assert_match(
      /1,000\.00/,
      response.body
    )

    assert_match(
      /800\.00/,
      response.body
    )

    assert_match(
      /500\.00/,
      response.body
    )

    assert_match(
      /300\.00/,
      response.body
    )

    assert_match(
      @purchase.purchase_number,
      response.body
    )

    assert_match(
      /Supplier credit/,
      response.body
    )
  end

  test "purchase financial values reflect return without rewriting invoice" do
    @purchase.reload

    assert_equal 1_000.to_d,
                 @purchase.total

    assert_equal 800.to_d,
                 @purchase.amount_paid

    assert_equal 200.to_d,
                 @purchase.balance_due

    assert_equal 500.to_d,
                 @purchase.completed_return_total

    assert_equal 0.to_d,
                 @purchase.effective_balance_due

    assert_equal 300.to_d,
                 @purchase.supplier_credit_due
  end

  test "supplier available credit equals unapplied credit" do
    assert_equal 300.to_d,
                 @supplier
                   .reload
                   .available_credit_balance

    assert_equal 300.to_d,
                 @supplier_credit.available_amount

    assert @supplier_credit.available?
  end

  private

  def create_received_purchase
    purchase =
      @organization.purchases.create!(
        branch: @branch,
        supplier: @supplier,
        recorded_by: @owner,
        purchase_number:
          "SUP-ACCOUNT-PUR-#{SecureRandom.hex(4).upcase}",
        supplier_invoice_number:
          "SUP-ACCOUNT-INV-#{SecureRandom.hex(4).upcase}",
        status: "received",
        payment_status: "unpaid",
        purchased_on: Date.current,
        due_on:
          30.days.from_now.to_date,
        received_at: Time.current,
        prices_include_tax: true,
        subtotal: 1_000,
        discount_total: 0,
        tax_total: 0,
        total: 1_000,
        amount_paid: 0,
        balance_due: 1_000
      )

    unit =
      @item.unit_of_measure

    line =
      purchase.purchase_lines.create!(
        organization: @organization,
        item: @item,
        line_number: 1,
        item_name: @item.name,
        sku: @item.sku,
        barcode: @item.barcode,
        item_type: "product",
        unit_name: unit.name,
        unit_symbol: unit.symbol,
        quantity: 4,
        unit_cost: 250,
        gross_amount: 1_000,
        discount_amount: 0,
        tax_percentage: 0,
        tax_amount: 0,
        line_total: 1_000
      )

    Inventory::PostMovement.call(
      organization: @organization,
      branch: @branch,
      item: @item,
      recorded_by: @owner,
      movement_type: "purchase",
      quantity_change: 4,
      occurred_at: Time.current,
      reference:
        purchase.supplier_invoice_number,
      source: purchase
    )

    [
      purchase,
      line
    ]
  end
end
