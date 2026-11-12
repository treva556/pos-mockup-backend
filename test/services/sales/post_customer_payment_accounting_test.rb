require "test_helper"

class Sales::PostCustomerPaymentAccountingTest <
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

    @customer =
      create_customer(
        organization: @organization
      )

    @payment_method =
      create_payment_method(
        organization: @organization,
        overrides: {
          name: "Accounting Customer Cash"
        }
      )

    @cash_ledger =
      @organization
        .ledger_accounts
        .create!(
          code: "1017",
          name: "Customer Payment Cash",
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
          name: "Customer Payment Till"
        }
      )

    @money_account.update!(
      ledger_account:
        @cash_ledger
    )

    @sale =
      @organization
        .sales
        .create!(
          branch: @branch,
          customer: @customer,
          cashier: @user,
          sale_number: "CPAY-000001",
          status: "completed",
          payment_status: "unpaid",
          sold_at: Time.current,
          due_on:
            Date.current + 30.days,
          prices_include_tax: true,
          subtotal: 1_000,
          discount_total: 0,
          tax_total: 0,
          total: 1_000,
          amount_paid: 0,
          balance_due: 1_000,
          change_given: 0
        )

    @payment =
      @sale
        .sale_payments
        .create!(
          organization: @organization,
          payment_method:
            @payment_method,
          money_account:
            @money_account,
          recorded_by: @user,
          amount: 400,
          amount_tendered: 400,
          change_given: 0,
          paid_at: Time.current
        )
  end

  test "posts customer payment against receivable" do
    journal =
      Sales::PostCustomerPaymentAccounting.call(
        organization: @organization,
        payment: @payment
      )

    assert journal.status_posted?
    assert journal.balanced?

    assert_equal(
      @payment,
      journal.source
    )

    cash_line =
      journal
        .journal_lines
        .find_by!(
          ledger_account:
            @cash_ledger
        )

    assert_equal(
      400.to_d,
      cash_line.debit
    )

    assert_equal(
      0.to_d,
      cash_line.credit
    )

    receivable =
      mapped_account(
        "accounts_receivable"
      )

    receivable_line =
      journal
        .journal_lines
        .find_by!(
          ledger_account:
            receivable
        )

    assert_equal(
      0.to_d,
      receivable_line.debit
    )

    assert_equal(
      400.to_d,
      receivable_line.credit
    )
  end

  test "posting same payment twice is idempotent" do
    first =
      Sales::PostCustomerPaymentAccounting.call(
        organization: @organization,
        payment: @payment
      )

    assert_no_difference(
      "JournalEntry.count"
    ) do
      second =
        Sales::PostCustomerPaymentAccounting.call(
          organization: @organization,
          payment: @payment
        )

      assert_equal(
        first.id,
        second.id
      )
    end
  end

  test "fails when money account is not linked to ledger" do
    @money_account.update!(
      ledger_account: nil
    )

    assert_no_difference(
      "JournalEntry.count"
    ) do
      assert_raises(
        Sales::InvalidCustomerPaymentError
      ) do
        Sales::PostCustomerPaymentAccounting.call(
          organization: @organization,
          payment: @payment
        )
      end
    end
  end

  private

  def mapped_account(role)
    @organization
      .accounting_account_mappings
      .find_by!(
        role: role
      )
      .ledger_account
  end
end
