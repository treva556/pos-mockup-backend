require "test_helper"

class Sales::PostSaleAccountingTest <
  ActiveSupport::TestCase
  setup do
    @user =
      create_user

    @organization =
      provision_organization_for(
        @user
      )

    @branch =
      @organization.main_branch

    @payment_method =
      create_payment_method(
        organization: @organization,
        overrides: {
          name: "Accounting Cash"
        }
      )

    @cash_ledger =
      @organization
        .ledger_accounts
        .create!(
          code: "1015",
          name: "Accounting Test Cash",
          account_type: "asset",
          normal_balance: "debit",
          report_group: "current_asset",
          postable: true,
          active: true,
          system_account: false
        )

    @money_account =
      create_money_account(
        organization: @organization,
        overrides: {
          name: "Accounting Test Till"
        }
      )

    @money_account.update!(
      ledger_account:
        @cash_ledger
    )
  end

  test "posts fully paid taxable sale" do
    sale =
      create_sale(
        amount_paid: 116,
        balance_due: 0
      )

    create_payment(
      sale: sale,
      amount: 116
    )

    journal =
      Sales::PostSaleAccounting.call(
        organization: @organization,
        sale: sale
      )

    assert journal.status_posted?
    assert_equal sale, journal.source
    assert journal.balanced?

    assert_line(
      journal: journal,
      account: @cash_ledger,
      debit: 116,
      credit: 0
    )

    assert_line(
      journal: journal,
      account:
        mapped_account(
          "sales_revenue"
        ),
      debit: 0,
      credit: 100
    )

    assert_line(
      journal: journal,
      account:
        mapped_account(
          "output_tax"
        ),
      debit: 0,
      credit: 16
    )
  end

  test "posts credit sale to accounts receivable" do
    customer =
      create_customer(
        organization: @organization
      )

    sale =
      create_sale(
        customer: customer,
        amount_paid: 0,
        balance_due: 116
      )

    journal =
      Sales::PostSaleAccounting.call(
        organization: @organization,
        sale: sale
      )

    assert_line(
      journal: journal,
      account:
        mapped_account(
          "accounts_receivable"
        ),
      debit: 116,
      credit: 0
    )

    assert_line(
      journal: journal,
      account:
        mapped_account(
          "sales_revenue"
        ),
      debit: 0,
      credit: 100
    )

    assert_line(
      journal: journal,
      account:
        mapped_account(
          "output_tax"
        ),
      debit: 0,
      credit: 16
    )

    assert journal.balanced?
  end

  test "posts partial sale between cash and receivable" do
    customer =
      create_customer(
        organization: @organization
      )

    sale =
      create_sale(
        customer: customer,
        amount_paid: 40,
        balance_due: 76
      )

    create_payment(
      sale: sale,
      amount: 40
    )

    journal =
      Sales::PostSaleAccounting.call(
        organization: @organization,
        sale: sale
      )

    assert_line(
      journal: journal,
      account: @cash_ledger,
      debit: 40,
      credit: 0
    )

    assert_line(
      journal: journal,
      account:
        mapped_account(
          "accounts_receivable"
        ),
      debit: 76,
      credit: 0
    )

    assert_equal(
      116.to_d,
      journal.total_debits
    )

    assert_equal(
      116.to_d,
      journal.total_credits
    )
  end

  test "posting same sale twice is idempotent" do
    sale =
      create_sale(
        amount_paid: 116,
        balance_due: 0
      )

    create_payment(
      sale: sale,
      amount: 116
    )

    first =
      Sales::PostSaleAccounting.call(
        organization: @organization,
        sale: sale
      )

    assert_no_difference(
      "JournalEntry.count"
    ) do
      second =
        Sales::PostSaleAccounting.call(
          organization: @organization,
          sale: sale
        )

      assert_equal(
        first.id,
        second.id
      )
    end
  end

  test "fails when payment money account has no ledger account" do
    sale =
      create_sale(
        amount_paid: 116,
        balance_due: 0
      )

    create_payment(
      sale: sale,
      amount: 116
    )

    @money_account.update!(
      ledger_account: nil
    )

    assert_no_difference(
      "JournalEntry.count"
    ) do
      error =
        assert_raises(
          Sales::CompletionError
        ) do
          Sales::PostSaleAccounting.call(
            organization: @organization,
            sale: sale
          )
        end

      assert_match(
        /not linked to a ledger account/,
        error.message
      )
    end
  end

  private

  def create_sale(
    customer: nil,
    amount_paid:,
    balance_due:
  )
    @organization
      .sales
      .create!(
        branch: @branch,
        customer: customer,
        cashier: @user,
        sale_number:
          "ACC-#{SecureRandom.hex(5).upcase}",
        status: "completed",
        payment_status:
          payment_status_for(
            amount_paid: amount_paid,
            balance_due: balance_due
          ),
        sold_at: Time.current,
        due_on:
          balance_due.to_d.positive? ?
            Date.current + 30.days :
            nil,
        prices_include_tax: true,
        subtotal: 100,
        discount_total: 0,
        tax_total: 16,
        total: 116,
        amount_paid: amount_paid,
        balance_due: balance_due,
        change_given: 0
      )
  end

  def create_payment(
    sale:,
    amount:
  )
    sale
      .sale_payments
      .create!(
        organization: @organization,
        payment_method:
          @payment_method,
        money_account:
          @money_account,
        recorded_by: @user,
        amount: amount,
        amount_tendered: amount,
        change_given: 0,
        paid_at: sale.sold_at
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
    account:,
    debit:,
    credit:
  )
    line =
      journal
        .journal_lines
        .find_by!(
          ledger_account:
            account
        )

    assert_equal(
      debit.to_d,
      line.debit
    )

    assert_equal(
      credit.to_d,
      line.credit
    )
  end

  def payment_status_for(
    amount_paid:,
    balance_due:
  )
    return "paid" if balance_due.to_d.zero?
    return "unpaid" if amount_paid.to_d.zero?

    "partially_paid"
  end
end
