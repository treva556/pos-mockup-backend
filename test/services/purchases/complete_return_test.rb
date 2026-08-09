require "test_helper"

module Purchases
  class CompleteReturnTest <
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
            "Return Supplier #{SecureRandom.hex(4)}",
          active: true,
          payment_terms_days: 30
        )

      @item =
        create_inventory_item(
          organization: @organization,
          overrides: {
            name: "Returnable Paint",
            purchase_cost: 250
          }
        )

      @payment_method =
        create_payment_method(
          organization: @organization,
          overrides: {
            name: "Bank Transfer"
          }
        )

      @money_account =
        create_money_account(
          organization: @organization,
          overrides: {
            name: "Purchases Bank",
            account_type: "bank",
            opening_balance: 20_000,
            opening_balance_date: Date.current,
            can_pay: true,
            can_receive: true
          }
        )
    end

    test "completes purchase return and removes stock" do
      purchase, source_line, =
        create_received_purchase(
          item: @item,
          quantity: 4,
          unit_cost: 250
        )

      assert_equal 4.to_d,
                   stock_quantity(@item)

      purchase_return = nil

      assert_difference(
        "PurchaseReturn.count",
        1
      ) do
        assert_difference(
          "PurchaseReturnLine.count",
          1
        ) do
          assert_difference(
            "StockMovement.count",
            1
          ) do
            purchase_return =
              complete_return(
                purchase: purchase,
                line: source_line,
                quantity: 1
              )
          end
        end
      end

      assert purchase_return.completed?

      assert_match(
        /-PRET-\d{6}\z/,
        purchase_return.return_number
      )

      assert_equal 250.to_d,
                   purchase_return.total

      assert_equal 3.to_d,
                   stock_quantity(@item)

      source_line.reload

      assert_equal 1.to_d,
                   source_line.returned_quantity

      assert_equal 3.to_d,
                   source_line.returnable_quantity

      movement =
        purchase_return
          .stock_movements
          .first

      assert_equal "purchase_return",
                   movement.movement_type

      assert_equal(-1.to_d,
                   movement.quantity_change)

      assert_equal purchase_return,
                   movement.source

      purchase.reload

      assert_equal 1_000.to_d,
                   purchase.balance_due

      assert_equal 750.to_d,
                   purchase.effective_balance_due
    end

    test "rejects returning more than remaining quantity" do
      purchase, source_line, =
        create_received_purchase(
          item: @item,
          quantity: 2,
          unit_cost: 250
        )

      complete_return(
        purchase: purchase,
        line: source_line,
        quantity: 1
      )

      assert_equal 1.to_d,
                   source_line.reload.returnable_quantity

      stock_before =
        stock_quantity(@item)

      assert_no_difference(
        "PurchaseReturn.count"
      ) do
        assert_no_difference(
          "StockMovement.count"
        ) do
          assert_raises(
            Purchases::ReturnError
          ) do
            complete_return(
              purchase: purchase,
              line: source_line,
              quantity: 2
            )
          end
        end
      end

      assert_equal stock_before,
                   stock_quantity(@item)

      assert_equal 1.to_d,
                   source_line.reload.returnable_quantity
    end

    test "expiry purchase return deducts original batch" do
      expiry_item =
        create_inventory_item(
          organization: @organization,
          overrides: {
            name: "Returnable Juice",
            purchase_cost: 100,
            tracks_expiry: true
          }
        )

      purchase,
        source_line,
        batch =
        create_received_purchase(
          item: expiry_item,
          quantity: 5,
          unit_cost: 100
        )

      assert_equal 5.to_d,
                   batch.quantity_remaining

      assert_equal 5.to_d,
                   stock_quantity(expiry_item)

      purchase_return =
        complete_return(
          purchase: purchase,
          line: source_line,
          quantity: 2
        )

      assert_equal 3.to_d,
                   batch.reload.quantity_remaining

      assert_equal 3.to_d,
                   stock_quantity(expiry_item)

      return_line =
        purchase_return
          .purchase_return_lines
          .first

      assert_equal batch,
                   return_line.inventory_batch

      movement =
        purchase_return
          .stock_movements
          .first

      assert_equal batch,
                   movement.inventory_batch

      assert_equal(-2.to_d,
                   movement.quantity_change)
    end

    test "rolls back return when stock is unavailable" do
      purchase, source_line, =
        create_received_purchase(
          item: @item,
          quantity: 2,
          unit_cost: 250
        )

      Inventory::PostMovement.call(
        organization: @organization,
        branch: @branch,
        item: @item,
        recorded_by: @owner,
        movement_type: "sale",
        quantity_change: -2,
        occurred_at: Time.current,
        reference: "TEST-STOCK-USE"
      )

      assert_equal 0.to_d,
                   stock_quantity(@item)

      sequence_before =
        @branch
          .reload
          .next_purchase_return_sequence

      assert_no_difference(
        "PurchaseReturn.count"
      ) do
        assert_no_difference(
          "PurchaseReturnLine.count"
        ) do
          assert_no_difference(
            "StockMovement.count"
          ) do
            assert_raises(
              Purchases::ReturnError
            ) do
              complete_return(
                purchase: purchase,
                line: source_line,
                quantity: 1
              )
            end
          end
        end
      end

      assert_equal 0.to_d,
                   stock_quantity(@item)

      assert_equal(
        sequence_before,
        @branch
          .reload
          .next_purchase_return_sequence
      )

      assert_equal 0.to_d,
                   source_line.reload.returned_quantity
    end

    test "purchase return reduces effective supplier debt" do
      purchase, source_line, =
        create_received_purchase(
          item: @item,
          quantity: 4,
          unit_cost: 250
        )

      assert_equal 1_000.to_d,
                   purchase.balance_due

      assert_equal 1_000.to_d,
                   purchase.effective_balance_due

      purchase_return =
        complete_return(
          purchase: purchase,
          line: source_line,
          quantity: 1
        )

      assert_equal 250.to_d,
                   purchase_return.total

      purchase.reload

      assert_equal 1_000.to_d,
                   purchase.balance_due

      assert_equal 750.to_d,
                   purchase.effective_balance_due

      assert_equal 750.to_d,
                   @supplier.reload.outstanding_balance

      assert_equal 0.to_d,
                   purchase_return.supplier_credit_due
    end

    test "supplier payment cannot exceed effective balance" do
      purchase, source_line, =
        create_received_purchase(
          item: @item,
          quantity: 5,
          unit_cost: 200
        )

      complete_return(
        purchase: purchase,
        line: source_line,
        quantity: 2
      )

      purchase.reload

      assert_equal 1_000.to_d,
                   purchase.balance_due

      assert_equal 600.to_d,
                   purchase.effective_balance_due

      assert_no_difference(
        "PurchasePayment.count"
      ) do
        assert_raises(
          Purchases::InvalidSupplierPaymentError
        ) do
          record_supplier_payment(
            purchase: purchase,
            amount: 700
          )
        end
      end

      payment =
        record_supplier_payment(
          purchase: purchase,
          amount: 600
        )

      assert_equal 600.to_d,
                   payment.amount

      purchase.reload

      assert_equal 600.to_d,
                   purchase.amount_paid

      assert_equal 400.to_d,
                   purchase.balance_due

      assert_equal 0.to_d,
                   purchase.effective_balance_due

      assert purchase.payment_partially_paid?
      refute purchase.outstanding?
    end

    private

    def create_received_purchase(
      item:,
      quantity:,
      unit_cost:
    )
      total =
        quantity.to_d *
          unit_cost.to_d

      purchase =
        @organization.purchases.create!(
          branch: @branch,
          supplier: @supplier,
          recorded_by: @owner,
          purchase_number:
            "TEST-PUR-#{SecureRandom.hex(5).upcase}",
          supplier_invoice_number:
            "INV-#{SecureRandom.hex(4).upcase}",
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

      source_line =
        purchase.purchase_lines.create!(
          organization: @organization,
          item: item,
          line_number: 1,
          item_name: item.name,
          sku: item.sku,
          barcode: item.barcode,
          item_type:
            item.stockable? ? "product" : "service",
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

      batch = nil

      if item.tracks_expiry?
        batch =
          @organization
            .inventory_batches
            .create!(
              branch: @branch,
              item: item,
              purchase_line: source_line,
              batch_number:
                "RET-#{SecureRandom.hex(4).upcase}",
              expires_on:
                30.days.from_now.to_date,
              quantity_received: quantity,
              quantity_remaining: quantity,
              unit_cost: unit_cost,
              received_at: Time.current,
              status: "active"
            )
      end

      if item.stockable?
        Inventory::PostMovement.call(
          organization: @organization,
          branch: @branch,
          item: item,
          recorded_by: @owner,
          movement_type: "purchase",
          quantity_change: quantity,
          occurred_at: Time.current,
          reference:
            purchase.supplier_invoice_number,
          source: purchase,
          inventory_batch: batch
        )
      end

      [
        purchase,
        source_line,
        batch
      ]
    end

    def complete_return(
      purchase:,
      line:,
      quantity:
    )
      Purchases::CompleteReturn.call(
        organization: @organization,
        purchase: purchase,
        recorded_by: @owner,
        lines: [
          {
            purchase_line_id: line.id,
            quantity: quantity
          }
        ],
        reason_code: "wrong_item",
        returned_at: Time.current
      )
    end

    def record_supplier_payment(
      purchase:,
      amount:
    )
      Purchases::RecordSupplierPayment.call(
        organization: @organization,
        purchase: purchase,
        payment_method: @payment_method,
        money_account: @money_account,
        recorded_by: @owner,
        amount: amount,
        paid_at: Time.current
      )
    end

    def stock_quantity(item)
      @organization
        .stock_levels
        .find_by(
          branch: @branch,
          item: item
        )
        &.quantity_on_hand
        .to_d
    end
  end
end
