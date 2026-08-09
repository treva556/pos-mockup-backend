require "test_helper"

module Sales
  class CompleteReturnTest <
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
            name: "Returnable Paint",
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

    test "completes a partial sale return and restores stock" do
      sale =
        create_paid_sale(
          item: @item,
          quantity: 4
        )

      assert_equal 6.to_d,
                   stock_quantity(@item)

      original_total =
        sale.total

      original_paid =
        sale.amount_paid

      original_balance =
        sale.balance_due

      sale_return = nil

      assert_difference(
        "SaleReturn.count",
        1
      ) do
        assert_difference(
          "SaleReturnLine.count",
          1
        ) do
          assert_difference(
            "StockMovement.count",
            1
          ) do
            sale_return =
              complete_return(
                sale: sale,
                quantity: 1
              )
          end
        end
      end

      assert sale_return.completed?

      assert_match(
        /-SRET-\d{6}\z/,
        sale_return.return_number
      )

      assert_equal 500.to_d,
                   sale_return.subtotal

      assert_equal 0.to_d,
                   sale_return.discount_total

      assert_equal 500.to_d,
                   sale_return.total

      return_line =
        sale_return.sale_return_lines.first

      assert_equal 1.to_d,
                   return_line.quantity

      assert_equal 500.to_d,
                   return_line.gross_amount

      assert_equal 500.to_d,
                   return_line.line_total

      assert return_line.stock_restock?

      assert_equal 7.to_d,
                   stock_quantity(@item)

      source_line =
        sale.sale_lines.first

      assert_equal 1.to_d,
                   source_line.returned_quantity

      assert_equal 3.to_d,
                   source_line.returnable_quantity

      movement =
        sale_return.stock_movements.first

      assert_equal "sale_return",
                   movement.movement_type

      assert_equal 1.to_d,
                   movement.quantity_change

      assert_equal sale_return,
                   movement.source

      sale.reload

      assert_equal original_total,
                   sale.total

      assert_equal original_paid,
                   sale.amount_paid

      assert_equal original_balance,
                   sale.balance_due
    end

    test "rejects returning more than the remaining quantity" do
      sale =
        create_paid_sale(
          item: @item,
          quantity: 2
        )

      complete_return(
        sale: sale,
        quantity: 1
      )

      source_line =
        sale.sale_lines.first

      assert_equal 1.to_d,
                   source_line.returnable_quantity

      stock_before =
        stock_quantity(@item)

      assert_no_difference(
        "SaleReturn.count"
      ) do
        assert_no_difference(
          "SaleReturnLine.count"
        ) do
          assert_no_difference(
            "StockMovement.count"
          ) do
            assert_raises(
              Sales::ReturnError
            ) do
              complete_return(
                sale: sale,
                quantity: 2
              )
            end
          end
        end
      end

      assert_equal stock_before,
                   stock_quantity(@item)

      assert_equal 1.to_d,
                   source_line.reload.returnable_quantity
    end

    test "damaged return does not increase sellable stock" do
      sale =
        create_paid_sale(
          item: @item,
          quantity: 2
        )

      stock_before =
        stock_quantity(@item)

      sale_return = nil

      assert_difference(
        "SaleReturn.count",
        1
      ) do
        assert_no_difference(
          "StockMovement.count"
        ) do
          sale_return =
            complete_return(
              sale: sale,
              quantity: 1,
              disposition: "damaged"
            )
        end
      end

      assert sale_return.completed?

      assert sale_return
        .sale_return_lines
        .first
        .stock_damaged?

      assert_equal stock_before,
                   stock_quantity(@item)
    end

    test "credit sale return reduces effective customer debt" do
      sale =
        create_credit_sale(
          item: @item,
          quantity: 2
        )

      assert_equal 1_000.to_d,
                   sale.balance_due

      assert_equal 1_000.to_d,
                   sale.effective_balance_due

      sale_return =
        complete_return(
          sale: sale,
          quantity: 1
        )

      assert_equal 500.to_d,
                   sale_return.total

      sale.reload

      assert_equal 1_000.to_d,
                   sale.balance_due

      assert_equal 500.to_d,
                   sale.effective_balance_due

      assert_equal 500.to_d,
                   @customer.reload.outstanding_balance

      assert_equal 0.to_d,
                   sale.available_return_refund
    end

    test "restores an expiry tracked item to its original batch" do
      expiry_item =
        create_inventory_item(
          organization: @organization,
          overrides: {
            name: "Fresh Juice",
            selling_price: 200,
            purchase_cost: 100,
            tracks_expiry: true
          }
        )

      batch =
        @organization.inventory_batches.create!(
          branch: @branch,
          item: expiry_item,
          batch_number: "RETURN-BATCH-001",
          expires_on:
            30.days.from_now.to_date,
          quantity_received: 5,
          quantity_remaining: 5,
          unit_cost: 100,
          received_at: Time.current
        )

      Inventory::PostMovement.call(
        organization: @organization,
        branch: @branch,
        item: expiry_item,
        recorded_by: @owner,
        movement_type: "purchase",
        quantity_change: 5,
        inventory_batch: batch
      )

      sale =
        create_paid_sale(
          item: expiry_item,
          quantity: 2
        )

      assert_equal 3.to_d,
                   batch.reload.quantity_remaining

      assert_equal 3.to_d,
                   stock_quantity(expiry_item)

      sale_return =
        complete_return(
          sale: sale,
          quantity: 1,
          batch: batch
        )

      assert_equal 4.to_d,
                   batch.reload.quantity_remaining

      assert batch.active?

      assert_equal 4.to_d,
                   stock_quantity(expiry_item)

      return_line =
        sale_return.sale_return_lines.first

      assert_equal batch,
                   return_line.inventory_batch

      movement =
        sale_return.stock_movements.first

      assert_equal batch,
                   movement.inventory_batch
    end

   test "rolls back the whole return when stock posting fails" do
      sale =
        create_paid_sale(
          item: @item,
          quantity: 2
        )

      stock_before =
        stock_quantity(@item)

      sequence_before =
        @branch
          .reload
          .next_sale_return_sequence

      service =
        Sales::CompleteReturn.new(
          organization: @organization,
          sale: sale,
          recorded_by: @owner,
          reason_code: "other",
          lines: [
            {
              sale_line_id:
                sale.sale_lines.first.id,
              quantity: 1,
              stock_disposition: "restock"
            }
          ]
        )

      service.define_singleton_method(
        :post_return_movement!
      ) do |**_arguments|
        raise RuntimeError,
              "forced stock failure"
      end

      assert_no_difference(
        "SaleReturn.count"
      ) do
        assert_no_difference(
          "SaleReturnLine.count"
        ) do
          assert_no_difference(
            "StockMovement.count"
          ) do
            error =
              assert_raises(
                RuntimeError
              ) do
                service.call
              end

            assert_equal(
              "forced stock failure",
              error.message
            )
          end
        end
      end

      assert_equal stock_before,
                  stock_quantity(@item)

      assert_equal(
        sequence_before,
        @branch
          .reload
          .next_sale_return_sequence
      )

      assert_equal 0.to_d,
                  sale
                    .sale_lines
                    .first
                    .returned_quantity
    end

    test "completed sale return audit records cannot be changed" do
      sale =
        create_paid_sale(
          item: @item,
          quantity: 2
        )

      sale_return =
        complete_return(
          sale: sale,
          quantity: 1
        )

      return_line =
        sale_return.sale_return_lines.first

      movement =
        sale_return.stock_movements.first

      original_return_total =
        sale_return.total

      original_line_quantity =
        return_line.quantity

      original_movement_quantity =
        movement.quantity_change

      assert_not sale_return.update(
        total: 1
      )

      assert_not return_line.update(
        quantity: 99
      )

      assert_not movement.update(
        quantity_change: 99
      )

      assert_equal(
        original_return_total,
        sale_return.reload.total
      )

      assert_equal(
        original_line_quantity,
        return_line.reload.quantity
      )

      assert_equal(
        original_movement_quantity,
        movement.reload.quantity_change
      )
    end

    test "completed sale return audit records cannot be destroyed" do
      sale =
        create_paid_sale(
          item: @item,
          quantity: 2
        )

      sale_return =
        complete_return(
          sale: sale,
          quantity: 1
        )

      return_line =
        sale_return.sale_return_lines.first

      movement =
        sale_return.stock_movements.first

      return_id =
        sale_return.id

      line_id =
        return_line.id

      movement_id =
        movement.id

      assert_not return_line.destroy
      assert_not movement.destroy
      assert_not sale_return.destroy

      assert SaleReturn.exists?(return_id)
      assert SaleReturnLine.exists?(line_id)
      assert StockMovement.exists?(movement_id)
    end

    test "customer refund audit record cannot be changed or destroyed" do
      sale =
        create_paid_sale(
          item: @item,
          quantity: 2
        )

      sale_return =
        complete_return(
          sale: sale,
          quantity: 1
        )

      refund =
        CustomerRefund.create!(
          organization: @organization,
          sale_return: sale_return,
          payment_method: @cash_method,
          money_account: @cash_account,
          recorded_by: @owner,
          amount: 100,
          refunded_at: Time.current,
          reference: "AUDIT-REFUND-001"
        )

      original_amount =
        refund.amount

      original_reference =
        refund.reference

      assert_not refund.update(
        amount: 1,
        reference: "TAMPERED"
      )

      refund.reload

      assert_equal(
        original_amount,
        refund.amount
      )

      assert_equal(
        original_reference,
        refund.reference
      )

      refund_id =
        refund.id

      assert_not refund.destroy

      assert CustomerRefund.exists?(
        refund_id
      )
    end

    private

    def create_paid_sale(
      item:,
      quantity:
    )
      cart =
        Sales::Cart.new(
          organization: @organization,
          branch: @branch
        )

      cart.customer_id =
        @customer.id

      cart.add_item(
        item: item,
        quantity: quantity
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

    def create_credit_sale(
      item:,
      quantity:
    )
      cart =
        Sales::Cart.new(
          organization: @organization,
          branch: @branch
        )

      cart.customer_id =
        @customer.id

      cart.add_item(
        item: item,
        quantity: quantity
      )

      plan =
        Sales::PaymentPlan.new(
          organization: @organization,
          branch: @branch,
          sale_total:
            cart.calculation.total
        )

      Sales::CompleteSale.call(
        organization: @organization,
        branch: @branch,
        cashier: @owner,
        cart: cart,
        payment_plan: plan,
        due_on:
          30.days.from_now.to_date
      )
    end

    def complete_return(
      sale:,
      quantity:,
      disposition: "restock",
      batch: nil
    )
      Sales::CompleteReturn.call(
        organization: @organization,
        sale: sale,
        recorded_by: @owner,
        reason_code: "other",
        lines: [
          {
            sale_line_id:
              sale.sale_lines.first.id,
            quantity: quantity,
            stock_disposition:
              disposition,
            inventory_batch_id:
              batch&.id
          }
        ]
      )
    end

    def stock_quantity(item)
      @organization
        .stock_levels
        .find_by!(
          branch: @branch,
          item: item
        )
        .quantity_on_hand
        .to_d
    end
  end
end
