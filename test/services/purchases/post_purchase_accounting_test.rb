require "test_helper"

class Purchases::PostPurchaseAccountingTest <
  ActiveSupport::TestCase
  setup do
    @owner =
      create_user

    @organization =
      provision_organization_for(
        @owner
      )

    @branch =
      @organization.main_branch

    @supplier =
      @organization
        .suppliers
        .create!(
          name: "Accounting Supplier",
          active: true
        )

    @purchase =
      @organization
        .purchases
        .create!(
          branch: @branch,
          supplier: @supplier,
          recorded_by: @owner,
          purchase_number: "PACCT-000001",
          status: "received",
          payment_status: "unpaid",
          purchased_on: Date.current,
          due_on: Date.current + 30.days,
          received_at: Time.current,
          prices_include_tax: true,
          subtotal: 116,
          discount_total: 0,
          tax_total: 16,
          total: 116,
          amount_paid: 0,
          balance_due: 116
        )
  end

  test "posts inventory input tax and payable" do
    journal =
      Purchases::PostPurchaseAccounting.call(
        organization: @organization,
        purchase: @purchase
      )

    assert journal.status_posted?
    assert journal.balanced?
    assert_equal @purchase, journal.source

    assert_line(
      journal,
      "inventory",
      debit: 100,
      credit: 0
    )

    assert_line(
      journal,
      "input_tax",
      debit: 16,
      credit: 0
    )

    assert_line(
      journal,
      "accounts_payable",
      debit: 0,
      credit: 116
    )
  end

  test "posting purchase twice is idempotent" do
    first =
      Purchases::PostPurchaseAccounting.call(
        organization: @organization,
        purchase: @purchase
      )

    assert_no_difference(
      "JournalEntry.count"
    ) do
      second =
        Purchases::PostPurchaseAccounting.call(
          organization: @organization,
          purchase: @purchase
        )

      assert_equal first.id,
                   second.id
    end
  end

  private

  def assert_line(
    journal,
    role,
    debit:,
    credit:
  )
    account =
      @organization
        .accounting_account_mappings
        .find_by!(
          role: role
        )
        .ledger_account

    line =
      journal
        .journal_lines
        .find_by!(
          ledger_account: account
        )

    assert_equal debit.to_d,
                 line.debit

    assert_equal credit.to_d,
                 line.credit
  end
end
