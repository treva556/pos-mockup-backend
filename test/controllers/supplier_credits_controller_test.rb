require "test_helper"

class SupplierCreditsControllerTest <
  ActionDispatch::IntegrationTest
  setup do
    @owner = create_user

    @organization =
      provision_organization_for(@owner)

    @branch =
      @organization.main_branch

    @supplier =
      @organization.suppliers.create!(
        name: "Supplier Credit UI Supplier",
        active: true,
        payment_terms_days: 30
      )

    @item =
      create_inventory_item(
        organization: @organization,
        overrides: {
          name: "Supplier Credit UI Item",
          purchase_cost: 250
        }
      )

    @payment_method =
      create_payment_method(
        organization: @organization,
        overrides: {
          name: "Supplier Bank"
        }
      )

    @money_account =
      create_money_account(
        organization: @organization,
        overrides: {
          name: "Supplier Credit Bank",
          account_type: "bank",
          opening_balance: 20_000,
          opening_balance_date:
            Date.current,
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

    @purchase.reload

    assert_equal 200.to_d,
                 @purchase.balance_due

    @purchase_return =
      Purchases::CompleteReturn.call(
        organization: @organization,
        purchase: @purchase,
        recorded_by: @owner,

        reason_code:
          "quality_issue",

        returned_at:
          Time.current,

        lines: [
          {
            purchase_line_id:
              @purchase_line.id,

            quantity: 2
          }
        ]
      )

    assert_equal 300.to_d,
                 @purchase_return
                   .uncredited_balance

    sign_in_as(@owner)
  end

  test "owner can open supplier credit form" do
    get new_purchase_return_supplier_credit_path(
      @purchase_return
    )

    assert_response :success

    assert_select "h1",
                  text: "Record Supplier Credit Note"

    assert_select(
      "input[name='supplier_credit[credit_number]']"
    )

    assert_select(
      "input[name='supplier_credit[amount]']"
    )
  end

  test "owner can record supplier credit note" do
    assert_difference(
      "SupplierCredit.count",
      1
    ) do
      post purchase_return_supplier_credits_path(
        @purchase_return
      ),
           params: {
             supplier_credit: {
               credit_number:
                 "CN-UI-001",

               issued_on:
                 Date.current,

               amount:
                 "300.00",

               notes:
                 "Supplier confirmed credit"
             }
           }
    end

    credit =
      @purchase_return
        .supplier_credits
        .order(:created_at)
        .last

    assert_equal "CN-UI-001",
                 credit.credit_number

    assert_equal 300.to_d,
                 credit.amount

    assert credit.available?

    assert_equal 300.to_d,
                 credit.available_amount

    assert_equal 0.to_d,
                 @purchase_return
                   .reload
                   .uncredited_balance

    assert_redirected_to(
      purchase_return_path(
        @purchase_return
      )
    )
  end

  test "credit above available amount is rejected" do
    assert_no_difference(
      "SupplierCredit.count"
    ) do
      post purchase_return_supplier_credits_path(
        @purchase_return
      ),
           params: {
             supplier_credit: {
               credit_number:
                 "CN-TOO-HIGH",

               issued_on:
                 Date.current,

               amount:
                 "301.00"
             }
           }
    end

    assert_response :unprocessable_entity

    assert_equal 300.to_d,
                 @purchase_return
                   .reload
                   .uncredited_balance
  end

  test "stock clerk cannot record supplier credit" do
    stock_clerk =
      create_user

    @organization.memberships.create!(
      user: stock_clerk,
      branch: @branch,
      role: "stock_clerk",
      active: true
    )

    delete logout_path

    sign_in_as(stock_clerk)

    get new_purchase_return_supplier_credit_path(
      @purchase_return
    )

    assert_redirected_to(
      dashboard_path
    )
  end

  test "cannot access another organizations purchase return" do
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
          name: "Foreign Credit Supplier",
          active: true,
          payment_terms_days: 30
        )

    foreign_item =
      create_inventory_item(
        organization:
          foreign_organization,
        overrides: {
          name: "Foreign Credit Item",
          purchase_cost: 100
        }
      )

    foreign_purchase =
      foreign_organization
        .purchases
        .create!(
          branch:
            foreign_branch,

          supplier:
            foreign_supplier,

          recorded_by:
            foreign_owner,

          purchase_number:
            "FOREIGN-PUR-001",

          supplier_invoice_number:
            "FOREIGN-INV-001",

          status:
            "received",

          payment_status:
            "unpaid",

          purchased_on:
            Date.current,

          due_on:
            30.days.from_now.to_date,

          received_at:
            Time.current,

          prices_include_tax:
            true,

          subtotal: 200,
          discount_total: 0,
          tax_total: 0,
          total: 200,
          amount_paid: 0,
          balance_due: 200
        )

    unit =
      foreign_item.unit_of_measure

    foreign_line =
      foreign_purchase
        .purchase_lines
        .create!(
          organization:
            foreign_organization,

          item:
            foreign_item,

          line_number: 1,

          item_name:
            foreign_item.name,

          sku:
            foreign_item.sku,

          barcode:
            foreign_item.barcode,

          item_type:
            "product",

          unit_name:
            unit.name,

          unit_symbol:
            unit.symbol,

          quantity: 2,
          unit_cost: 100,

          gross_amount: 200,
          discount_amount: 0,

          tax_percentage: 0,
          tax_amount: 0,

          line_total: 200
        )

    Inventory::PostMovement.call(
      organization:
        foreign_organization,

      branch:
        foreign_branch,

      item:
        foreign_item,

      recorded_by:
        foreign_owner,

      movement_type:
        "purchase",

      quantity_change:
        2,

      source:
        foreign_purchase
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
          "other",

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

    get new_purchase_return_supplier_credit_path(
      foreign_return
    )

    assert_response :not_found
  end

  private

  def create_received_purchase
    purchase =
      @organization.purchases.create!(
        branch: @branch,
        supplier: @supplier,
        recorded_by: @owner,

        purchase_number:
          "TEST-CREDIT-UI-PUR",

        supplier_invoice_number:
          "TEST-CREDIT-UI-INV",

        status: "received",
        payment_status: "unpaid",

        purchased_on:
          Date.current,

        due_on:
          30.days.from_now.to_date,

        received_at:
          Time.current,

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

        item_name:
          @item.name,

        sku:
          @item.sku,

        barcode:
          @item.barcode,

        item_type:
          "product",

        unit_name:
          unit.name,

        unit_symbol:
          unit.symbol,

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

      movement_type:
        "purchase",

      quantity_change:
        4,

      occurred_at:
        Time.current,

      reference:
        purchase.supplier_invoice_number,

      source:
        purchase
    )

    [
      purchase,
      line
    ]
  end
end
