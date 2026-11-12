require "test_helper"

module Sales
  class SaleReturnAccountingTest <
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

      @customer =
        create_customer(
          organization: @organization
        )

      @item =
        create_inventory_item(
          organization: @organization,
          overrides: {
            name: "Accounting Return Item",
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
            name: "Accounting Return Cash"
          }
        )

      @cash_ledger =
        @organization
          .ledger_accounts
          .create!(
            code: "1988",
            name: "Accounting Return Cash",
            account_type: "asset",
            normal_balance: "debit",
            report_group: "current_asset",
            postable: true,
            active: true,
            system_account: false
          )

      @cash_account =
        create_money_account(
          organization: @organization,
          overrides: {
            name: "Accounting Return Till"
          }
        )

      @cash_account.update!(
        ledger_account: @cash_ledger
      )
    end

    test "credit sale return reduces accounts receivable" do
      sale =
        create_sale(
          payment_amount: 0
        )

      assert_equal 1_000.to_d,
                   sale.balance_due

      sale_return =
        complete_return(
          sale: sale
        )

      journal =
        journal_for(
          sale_return
        )

      assert journal.status_posted?
      assert journal.balanced?

      assert_line(
        journal: journal,
        role: "sales_returns",
        debit: 500,
        credit: 0
      )

      assert_line(
        journal: journal,
        role: "accounts_receivable",
        debit: 0,
        credit: 500
      )

      assert_no_role_line(
        journal: journal,
        role: "customer_refund_payable"
      )

      assert_line(
        journal: journal,
        role: "inventory",
        debit: 300,
        credit: 0
      )

      assert_line(
        journal: journal,
        role: "cost_of_goods_sold",
        debit: 0,
        credit: 300
      )
    end

    test "partially paid sale return splits receivable and refund payable" do
      sale =
        create_sale(
          payment_amount: 700
        )

      assert_equal 300.to_d,
                   sale.balance_due

      sale_return =
        complete_return(
          sale: sale
        )

      journal =
        journal_for(
          sale_return
        )

      assert_line(
        journal: journal,
        role: "sales_returns",
        debit: 500,
        credit: 0
      )

      assert_line(
        journal: journal,
        role: "accounts_receivable",
        debit: 0,
        credit: 300
      )

      assert_line(
        journal: journal,
        role: "customer_refund_payable",
        debit: 0,
        credit: 200
      )

      assert journal.balanced?
    end

    test "paid sale return creates customer refund payable" do
      sale =
        create_sale(
          payment_amount: :full
        )

      sale_return =
        complete_return(
          sale: sale
        )

      journal =
        journal_for(
          sale_return
        )

      assert_line(
        journal: journal,
        role: "sales_returns",
        debit: 500,
        credit: 0
      )

      assert_line(
        journal: journal,
        role: "customer_refund_payable",
        debit: 0,
        credit: 500
      )

      assert_no_role_line(
        journal: journal,
        role: "accounts_receivable"
      )

      assert journal.balanced?
    end

    test "damaged return does not reverse inventory or cogs" do
      sale =
        create_sale(
          payment_amount: :full
        )

      stock_before =
        stock_quantity

      sale_return =
        complete_return(
          sale: sale,
          disposition: "damaged"
        )

      assert_equal(
        stock_before,
        stock_quantity
      )

      journal =
        journal_for(
          sale_return
        )

      assert_line(
        journal: journal,
        role: "sales_returns",
        debit: 500,
        credit: 0
      )

      assert_line(
        journal: journal,
        role: "customer_refund_payable",
        debit: 0,
        credit: 500
      )

      assert_no_role_line(
        journal: journal,
        role: "inventory"
      )

      assert_no_role_line(
        journal: journal,
        role: "cost_of_goods_sold"
      )

      assert journal.balanced?
    end

    test "customer refund settles refund payable against money account" do
      sale =
        create_sale(
          payment_amount: :full
        )

      sale_return =
        complete_return(
          sale: sale
        )

      refund =
        Sales::RecordCustomerRefund.call(
          organization: @organization,
          sale_return: sale_return,
          recorded_by: @owner,
          payment_method: @cash_method,
          money_account: @cash_account,
          amount: 500,
          refunded_at: Time.current
        )

      journal =
        journal_for(
          refund
        )

      assert journal.status_posted?
      assert journal.balanced?

      assert_line(
        journal: journal,
        role: "customer_refund_payable",
        debit: 500,
        credit: 0
      )

      cash_line =
        journal
          .journal_lines
          .find_by!(
            ledger_account:
              @cash_ledger
          )

      assert_equal 0.to_d,
                   cash_line.debit

      assert_equal 500.to_d,
                   cash_line.credit
    end

    test "posting same sale return twice is idempotent" do
      sale =
        create_sale(
          payment_amount: :full
        )

      sale_return =
        complete_return(
          sale: sale
        )

      first =
        journal_for(
          sale_return
        )

      assert_no_difference(
        "JournalEntry.count"
      ) do
        second =
          Sales::PostSaleReturnAccounting.call(
            organization: @organization,
            sale_return: sale_return
          )

        assert_equal first.id,
                     second.id
      end
    end

    private

    def create_sale(
      payment_amount:
    )
      cart =
        Sales::Cart.new(
          organization: @organization,
          branch: @branch
        )

      cart.customer_id =
        @customer.id

      cart.add_item(
        item: @item,
        quantity: 2
      )

      calculation =
        cart.calculation

      plan =
        Sales::PaymentPlan.new(
          organization: @organization,
          branch: @branch,
          sale_total:
            calculation.total
        )

      applied_amount =
        if payment_amount == :full
          calculation.total
        else
          payment_amount.to_d
        end

      if applied_amount.positive?
        plan.add_entry(
          payment_method_id:
            @cash_method.id,
          money_account_id:
            @cash_account.id,
          amount:
            applied_amount
        )
      end

      Sales::CompleteSale.call(
        organization: @organization,
        branch: @branch,
        cashier: @owner,
        cart: cart,
        payment_plan: plan,
        due_on:
          plan.balance_due.positive? ?
            30.days.from_now.to_date :
            nil
      )
    end

    def complete_return(
      sale:,
      disposition: "restock"
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
            quantity: 1,
            stock_disposition:
              disposition
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
