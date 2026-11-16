require "test_helper"

class AccountingAccountMappingTest <
  ActiveSupport::TestCase
  def setup
    @organization =
      build_organization(
        "Mapping Company"
      )

    @account =
      LedgerAccount.create!(
        organization: @organization,
        code: "1100",
        name: "Accounts Receivable",
        account_type: "asset",
        normal_balance: "debit",
        report_group: "current_asset",
        postable: true,
        active: true,
        system_account: false
      )
  end

  test "valid mapping" do
    mapping =
      AccountingAccountMapping.new(
        organization: @organization,
        ledger_account: @account,
        role: "accounts_receivable"
      )

    assert mapping.valid?
  end

  test "role is unique within organization" do
    AccountingAccountMapping.create!(
      organization: @organization,
      ledger_account: @account,
      role: "accounts_receivable"
    )

    duplicate =
      AccountingAccountMapping.new(
        organization: @organization,
        ledger_account: @account,
        role: "accounts_receivable"
      )

    assert_not duplicate.valid?
  end

  test "ledger account must belong to same organization" do
    other_organization =
      build_organization(
        "Other Mapping Company"
      )

    foreign_account =
      LedgerAccount.create!(
        organization: other_organization,
        code: "1100",
        name: "Accounts Receivable",
        account_type: "asset",
        normal_balance: "debit",
        report_group: "current_asset"
      )

    mapping =
      AccountingAccountMapping.new(
        organization: @organization,
        ledger_account: foreign_account,
        role: "accounts_receivable"
      )

    assert_not mapping.valid?

    assert_includes(
      mapping.errors[:ledger_account],
      "must belong to the same organization"
    )
  end

  test "mapped ledger account must be postable" do
    @account.update!(
      postable: false
    )

    mapping =
      AccountingAccountMapping.new(
        organization: @organization,
        ledger_account: @account,
        role: "accounts_receivable"
      )

    assert_not mapping.valid?
  end

  private

  def build_organization(name)
    Organization.create!(
      name: name,
      country_code: "KE",
      currency_code: "KES",
      time_zone: "Africa/Nairobi"
    )
  end
end
