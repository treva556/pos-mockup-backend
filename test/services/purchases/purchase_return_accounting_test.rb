require "test_helper"
module Purchases
  class PurchaseReturnAccountingTest <
    ActiveSupport::TestCase
    setup do
      @owner =
        create_user

      @organization =
        provision_organization_for(
          @owner
        )

      @organization.update!(
        accounting_enabled: true
      )

      @branch =
        @organization.main_branch

      @supplier =
        @organization.suppliers.create!(
          name: "Accounting Supplier",
          payment_terms_days: 30
        )

      @item =
        create_inventory_item(
          organization: @organization,
          overrides: {
            name: "Accounting Purchase Return Item",
            purchase_cost: 500,
            selling_price: 750
          }
        )
    end

    test "unpaid purchase return reduces accounts payable" do
      purchase =
        create_purchase(
          quantity: 2,
          unit_cost: 500,
          tax_amount: 0,
          total: 1_000,
          amount_paid: 0
        )

      purchase_return =
        complete_return(
          purchase: purchase,
          quantity: 1
        )

      journal =
        journal_for(
          purchase_return
        )

      assert journal.status_posted?
      assert journal.balanced?

      assert_line(
        journal: journal,
        role: "accounts_payable",
        debit: 500,
        credit: 0
      )

      assert_no_role_line(
        journal: journal,
        role: "supplier_credit_receivable"
      )

      assert_line(
        journal: journal,
        role: "inventory",
        debit: 0,
        credit: 500
      )
    end

    test "paid purchase return creates supplier credit receivable" do
      purchase =
        create_purchase(
          quantity: 2,
          unit_cost: 500,
          tax_amount: 0,
          total: 1_000,
          amount_paid: 1_000
        )

      purchase_return =
        complete_return(
          purchase: purchase,
          quantity: 1
        )

      journal =
        journal_for(
          purchase_return
        )

      assert_no_role_line(
        journal: journal,
        role: "accounts_payable"
      )

      assert_line(
        journal: journal,
        role: "supplier_credit_receivable",
        debit: 500,
        credit: 0
      )

      assert_line(
        journal: journal,
        role: "inventory",
        debit: 0,
        credit: 500
      )

      assert journal.balanced?
    end

    test "partially paid purchase return splits payable and supplier credit" do
      purchase =
        create_purchase(
          quantity: 2,
          unit_cost: 500,
          tax_amount: 0,
          total: 1_000,
          amount_paid: 700
        )

      assert_equal 300.to_d,
                   purchase.balance_due

      purchase_return =
        complete_return(
          purchase: purchase,
          quantity: 1
        )

      assert_equal 300.to_d,
                   purchase_return.debt_offset_amount

      assert_equal 200.to_d,
                   purchase_return.supplier_credit_due

      journal =
        journal_for(
          purchase_return
        )

      assert_line(
        journal: journal,
        role: "accounts_payable",
        debit: 300,
        credit: 0
      )

      assert_line(
        journal: journal,
        role: "supplier_credit_receivable",
        debit: 200,
        credit: 0
      )

      assert_line(
        journal: journal,
        role: "inventory",
        debit: 0,
        credit: 500
      )

      assert journal.balanced?
    end

    test "taxable purchase return reverses inventory and input tax" do
      purchase =
        create_purchase(
          quantity: 1,
          unit_cost: 116,
          tax_amount: 16,
          total: 116,
          amount_paid: 0
        )

      purchase_return =
        complete_return(
          purchase: purchase,
          quantity: 1
        )

      assert_equal 116.to_d,
                   purchase_return.total

      assert_equal 16.to_d,
                   purchase_return.tax_total

      journal =
        journal_for(
          purchase_return
        )

      assert_line(
        journal: journal,
        role: "accounts_payable",
        debit: 116,
        credit: 0
      )

      assert_line(
        journal: journal,
        role: "inventory",
        debit: 0,
        credit: 100
      )

      assert_line(
        journal: journal,
        role: "input_tax",
        debit: 0,
        credit: 16
      )

      assert journal.balanced?
    end

    test "posting the same purchase return twice is idempotent" do
      purchase =
        create_purchase(
          quantity: 2,
          unit_cost: 500,
          tax_amount: 0,
          total: 1_000,
          amount_paid: 0
        )

      purchase_return =
        complete_return(
          purchase: purchase,
          quantity: 1
        )

      first =
        journal_for(
          purchase_return
        )

      assert_no_difference(
        "JournalEntry.count"
      ) do
        second =
          Purchases::PostPurchaseReturnAccounting.call(
            organization: @organization,
            purchase_return: purchase_return
          )

        assert_equal first.id,
                     second.id
      end
    end

    test "accounting failure rolls back return and stock deduction" do
      purchase =
        create_purchase(
          quantity: 2,
          unit_cost: 500,
          tax_amount: 0,
          total: 1_000,
          amount_paid: 0
        )

      stock_before =
        stock_quantity

      singleton =
        class << Purchases::PostPurchaseReturnAccounting
          self
        end

      singleton.alias_method(
        :original_call_for_rollback_test,
        :call
      )

      singleton.define_method(
        :call
      ) do |**_arguments|
        raise Purchases::ReturnError,
              "forced accounting failure"
      end

      begin
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
                  quantity: 1
                )
              end
            end
          end
        end
      ensure
        singleton.alias_method(
          :call,
          :original_call_for_rollback_test
        )

        singleton.remove_method(
          :original_call_for_rollback_test
        )
      end

      assert_equal stock_before,
                   stock_quantity

      assert_equal 0.to_d,
                   purchase
                     .purchase_lines
                     .first
                     .returned_quantity
    end

    test "recording supplier credit does not create another journal" do
      purchase =
        create_purchase(
          quantity: 2,
          unit_cost: 500,
          tax_amount: 0,
          total: 1_000,
          amount_paid: 1_000
        )

      purchase_return =
        complete_return(
          purchase: purchase,
          quantity: 1
        )

      assert_equal 500.to_d,
                   purchase_return.supplier_credit_due

      assert_difference(
        "SupplierCredit.count",
        1
      ) do
        assert_no_difference(
          "JournalEntry.count"
        ) do
          Purchases::RecordSupplierCredit.call(
            organization: @organization,
            purchase_return: purchase_return,
            recorded_by: @owner,
            amount: 500,
            credit_number: "CN-ACCOUNTING-001",
            issued_on: Date.current
          )
        end
      end
    end

    private

    def create_purchase(
      quantity:,
      unit_cost:,
      tax_amount:,
      total:,
      amount_paid:
    )
      balance_due =
        total.to_d -
        amount_paid.to_d

      purchase =
        @organization.purchases.create!(
          branch: @branch,
          supplier: @supplier,
          recorded_by: @owner,
          purchase_number:
            "PUR-#{SecureRandom.hex(6).upcase}",
          supplier_invoice_number:
            "INV-#{SecureRandom.hex(6).upcase}",
          status: "received",
          payment_status:
            payment_status_for(
              amount_paid: amount_paid.to_d,
              balance_due: balance_due
            ),
          purchased_on: Date.current,
          due_on:
            30.days.from_now.to_date,
          received_at: Time.current,
          prices_include_tax: true,
          subtotal: total.to_d,
          discount_total: 0,
          tax_total: tax_amount.to_d,
          total: total.to_d,
          amount_paid: amount_paid.to_d,
          balance_due: balance_due,
          notes: nil
        )

      gross_amount =
        total.to_d

      purchase.purchase_lines.create!(
        organization: @organization,
        item: @item,
        tax_rate: nil,
        line_number: 1,
        item_name: @item.name,
        sku: @item.sku,
        barcode: @item.barcode,
        item_type: @item.item_type,
        unit_name:
          @item.unit_of_measure.name,
        unit_symbol:
          @item.unit_of_measure.symbol,
        quantity: quantity.to_d,
        unit_cost: unit_cost.to_d,
        gross_amount: gross_amount,
        discount_amount: 0,
        tax_percentage: 0,
        tax_amount: tax_amount.to_d,
        line_total: total.to_d
      )

      Inventory::PostMovement.call(
        organization: @organization,
        branch: @branch,
        item: @item,
        recorded_by: @owner,
        movement_type: "purchase",
        quantity_change:
          quantity.to_d,
        occurred_at: Time.current,
        reference:
          purchase.purchase_number,
        source: purchase
      )

      purchase
    end

    def complete_return(
      purchase:,
      quantity:
    )
      Purchases::CompleteReturn.call(
        organization: @organization,
        purchase: purchase,
        recorded_by: @owner,
        reason_code: "other",
        lines: [
          {
            purchase_line_id:
              purchase.purchase_lines.first.id,
            quantity: quantity
          }
        ]
      )
    end

    def journal_for(source)
      @organization
        .journal_entries
        .find_by!(
          source: source
        )
    end

    def mapped_account(role)
      @organization
        .accounting_account_mappings
        .find_by!(
          role: role
        )
        .ledger_account
    end

    def assert_line(
      journal:,
      role:,
      debit:,
      credit:
    )
      line =
        journal
          .journal_lines
          .find_by!(
            ledger_account:
              mapped_account(role)
          )

      assert_equal debit.to_d,
                   line.debit

      assert_equal credit.to_d,
                   line.credit
    end

    def assert_no_role_line(
      journal:,
      role:
    )
      assert_nil(
        journal
          .journal_lines
          .find_by(
            ledger_account:
              mapped_account(role)
          )
      )
    end

    def payment_status_for(
      amount_paid:,
      balance_due:
    )
      return "paid" if balance_due.zero?
      return "unpaid" if amount_paid.zero?

      "partially_paid"
    end

    def stock_quantity
      @organization
        .stock_levels
        .find_by!(
          branch: @branch,
          item: @item
        )
        .quantity_on_hand
        .to_d
    end
  end
end
