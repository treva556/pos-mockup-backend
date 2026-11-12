require "test_helper"

class Sales::CompleteSaleAccountingTest <
  ActiveSupport::TestCase
  setup do
    @user =
      create_user

    @organization =
      provision_organization_for(
        @user
      )

    @organization.update!(
      accounting_enabled: true
    )

    @branch =
      @organization.main_branch

    @cash_ledger =
      @organization
        .ledger_accounts
        .create!(
          code: "1016",
          name: "POS Integration Cash",
          account_type: "asset",
          normal_balance: "debit",
          report_group: "current_asset",
          postable: true,
          active: true,
          system_account: false
        )
  end

  test "completed sale can create a sale journal" do
    sale =
      @organization
        .sales
        .create!(
          branch: @branch,
          cashier: @user,
          sale_number: "INT-000001",
          status: "completed",
          payment_status: "unpaid",
          sold_at: Time.current,
          due_on: Date.current + 30.days,
          prices_include_tax: true,
          subtotal: 100,
          discount_total: 0,
          tax_total: 16,
          total: 116,
          amount_paid: 0,
          balance_due: 116,
          change_given: 0,
          customer:
            create_customer(
              organization: @organization
            )
        )

    assert_difference(
      "JournalEntry.count",
      1
    ) do
      Sales::PostSaleAccounting.call(
        organization: @organization,
        sale: sale
      )
    end

    journal =
      @organization
        .journal_entries
        .find_by!(
          source: sale
        )

    assert journal.status_posted?
    assert journal.balanced?
    assert_equal sale, journal.source
  end
end
