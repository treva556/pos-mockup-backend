require "test_helper"

module Purchases
  class RecordSupplierCreditTest <
    ActiveSupport::TestCase
    setup do
      @owner = create_user

      @organization =
        provision_organization_for(@owner)

      @branch =
        @organization.main_branch

      @supplier =
        @organization.suppliers.create!(
          name:
            "Credit Supplier #{SecureRandom.hex(4)}",
          active: true,
          payment_terms_days: 30
        )

      @item =
        create_inventory_item(
          organization: @organization,
          overrides: {
            name: "Supplier Credit Item",
            purchase_cost: 250
          }
        )

      @payment_method =
        create_payment_method(
          organization: @organization,
          overrides: {
            name: "Supplier Bank Payment"
          }
        )

      @money_account =
        create_money_account(
          organization: @organization,
          overrides: {
            name: "Supplier Credit Bank",
            account_type: "bank",
            opening_balance: 20_000,
            opening_balance_date: Date.current,
            can_pay: true,
            can_receive: true
          }
        )

      @purchase,
        @source_line =
        create_received_purchase

      record_payment(
        amount: 800
      )

      @purchase.reload

      assert_equal 200.to_d,
                   @purchase.balance_due

      @purchase_return =
        Purchases::CompleteReturn.call(
          organization: @organization,
          purchase: @purchase,
          recorded_by: @owner,
          lines: [
            {
              purchase_line_id:
                @source_line.id,
              quantity: 2
            }
          ],
          reason_code: "quality_issue",
          returned_at: Time.current
        )
    end

    test "excess return becomes available supplier credit" do
      assert_equal 500.to_d,
                   @purchase_return.total

      assert_equal 200.to_d,
                   @purchase_return.debt_offset_amount

      assert_equal 300.to_d,
                   @purchase_return.supplier_credit_due

      assert_equal 300.to_d,
                   @purchase_return.uncredited_balance

      @purchase.reload

      assert_equal 200.to_d,
                   @purchase.balance_due

      assert_equal 0.to_d,
                   @purchase.effective_balance_due

      credit = nil

      assert_difference(
        "SupplierCredit.count",
        1
      ) do
        credit =
          Purchases::RecordSupplierCredit.call(
            organization: @organization,
            purchase_return: @purchase_return,
            recorded_by: @owner,
            amount: 300,
            credit_number: "CN-TEST-001",
            issued_on: Date.current,
            notes: "Supplier issued credit note"
          )
      end

      assert credit.available?

      assert_equal 300.to_d,
                   credit.amount

      assert_equal 0.to_d,
                   credit.applied_amount

      assert_equal 300.to_d,
                   credit.available_amount

      assert_equal 0.to_d,
                   @purchase_return
                     .reload
                     .uncredited_balance

      assert_equal 300.to_d,
                   @supplier
                     .reload
                     .available_credit_balance
    end

    test "rejects supplier credit above return credit amount" do
      assert_equal 300.to_d,
                   @purchase_return.uncredited_balance

      assert_no_difference(
        "SupplierCredit.count"
      ) do
        assert_raises(
          Purchases::SupplierCreditError
        ) do
          Purchases::RecordSupplierCredit.call(
            organization: @organization,
            purchase_return: @purchase_return,
            recorded_by: @owner,
            amount: 301,
            credit_number: "CN-TOO-HIGH",
            issued_on: Date.current
          )
        end
      end

      assert_equal 300.to_d,
                   @purchase_return
                     .reload
                     .uncredited_balance
    end

    test "prevents duplicate credit beyond remaining balance" do
      Purchases::RecordSupplierCredit.call(
        organization: @organization,
        purchase_return: @purchase_return,
        recorded_by: @owner,
        amount: 200,
        credit_number: "CN-PARTIAL-001",
        issued_on: Date.current
      )

      assert_equal 100.to_d,
                   @purchase_return
                     .reload
                     .uncredited_balance

      assert_no_difference(
        "SupplierCredit.count"
      ) do
        assert_raises(
          Purchases::SupplierCreditError
        ) do
          Purchases::RecordSupplierCredit.call(
            organization: @organization,
            purchase_return: @purchase_return,
            recorded_by: @owner,
            amount: 101,
            credit_number: "CN-PARTIAL-002",
            issued_on: Date.current
          )
        end
      end

      final_credit =
        Purchases::RecordSupplierCredit.call(
          organization: @organization,
          purchase_return: @purchase_return,
          recorded_by: @owner,
          amount: 100,
          credit_number: "CN-PARTIAL-003",
          issued_on: Date.current
        )

      assert final_credit.available?

      assert_equal 0.to_d,
                   @purchase_return
                     .reload
                     .uncredited_balance

      assert_equal 300.to_d,
                   @supplier
                     .reload
                     .available_credit_balance
    end

    test "issued supplier credit financial identity cannot be changed" do
      credit =
        Purchases::RecordSupplierCredit.call(
          organization: @organization,
          purchase_return: @purchase_return,
          recorded_by: @owner,
          amount: 300,
          credit_number: "CN-LOCKED-001",
          issued_on: Date.current,
          notes: "Original supplier credit"
        )

      assert_not credit.update(
        amount: 999,
        credit_number: "CN-TAMPERED",
        notes: "Changed"
      )

      credit.reload

      assert_equal 300.to_d,
                   credit.amount

      assert_equal "CN-LOCKED-001",
                   credit.credit_number

      assert_equal(
        "Original supplier credit",
        credit.notes
      )
    end

    test "supplier credit application state can move forward" do
      credit =
        Purchases::RecordSupplierCredit.call(
          organization: @organization,
          purchase_return: @purchase_return,
          recorded_by: @owner,
          amount: 300,
          credit_number: "CN-STATE-001",
          issued_on: Date.current
        )

      assert credit.available?

      assert credit.update(
        applied_amount: 100,
        status: "partially_applied"
      )

      credit.reload

      assert_equal 100.to_d,
                   credit.applied_amount

      assert_equal 200.to_d,
                   credit.available_amount

      assert credit.partially_applied?

      assert credit.update(
        applied_amount: 300,
        status: "applied"
      )

      credit.reload

      assert_equal 300.to_d,
                   credit.applied_amount

      assert_equal 0.to_d,
                   credit.available_amount

      assert credit.applied?
    end

    test "supplier credit application state cannot move backward" do
      credit =
        Purchases::RecordSupplierCredit.call(
          organization: @organization,
          purchase_return: @purchase_return,
          recorded_by: @owner,
          amount: 300,
          credit_number: "CN-STATE-002",
          issued_on: Date.current
        )

      assert credit.update(
        applied_amount: 150,
        status: "partially_applied"
      )

      assert_not credit.update(
        applied_amount: 100,
        status: "partially_applied"
      )

      credit.reload

      assert_equal 150.to_d,
                   credit.applied_amount

      assert credit.partially_applied?

      assert_not credit.update(
        applied_amount: 0,
        status: "available"
      )

      credit.reload

      assert_equal 150.to_d,
                   credit.applied_amount

      assert credit.partially_applied?
    end

    private

    def create_received_purchase
      purchase =
        @organization.purchases.create!(
          branch: @branch,
          supplier: @supplier,
          recorded_by: @owner,
          purchase_number:
            "TEST-CREDIT-PUR-#{SecureRandom.hex(4).upcase}",
          supplier_invoice_number:
            "INV-CREDIT-#{SecureRandom.hex(4).upcase}",
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

      source_line =
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
        source_line
      ]
    end

    def record_payment(amount:)
      Purchases::RecordSupplierPayment.call(
        organization: @organization,
        purchase: @purchase,
        payment_method: @payment_method,
        money_account: @money_account,
        recorded_by: @owner,
        amount: amount,
        paid_at: Time.current
      )
    end
  end
end
