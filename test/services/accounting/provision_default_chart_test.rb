require "test_helper"

class Accounting::ProvisionDefaultChartTest <
  ActiveSupport::TestCase
  def setup
    @organization =
      Organization.create!(
        name: "Default Chart Company",
        country_code: "KE",
        currency_code: "KES",
        time_zone: "Africa/Nairobi"
      )
  end

  test "creates the default chart of accounts" do
    Accounting::ProvisionDefaultChart
      .new(
        organization: @organization
      )
      .call

    assert_equal(
      28,
      @organization
        .ledger_accounts
        .count
    )

    assert_equal(
      "Accounts Receivable",
      @organization
        .ledger_accounts
        .find_by!(
          code: "1100"
        )
        .name
    )

    assert_equal(
      "Sales Returns and Allowances",
      @organization
        .ledger_accounts
        .find_by!(
          code: "4090"
        )
        .name
    )
  end

  test "creates account hierarchy" do
    Accounting::ProvisionDefaultChart
      .new(
        organization: @organization
      )
      .call

    receivable =
      @organization
        .ledger_accounts
        .find_by!(
          code: "1100"
        )

    assert_equal(
      "1000",
      receivable.parent.code
    )
  end

  test "creates all system account mappings" do
    Accounting::ProvisionDefaultChart
      .new(
        organization: @organization
      )
      .call

    assert_equal(
      Accounting::ProvisionDefaultChart::MAPPINGS.size,
      @organization
        .accounting_account_mappings
        .count
    )

    mapping =
      @organization
        .accounting_account_mappings
        .find_by!(
          role: "sales_revenue"
        )

    assert_equal(
      "4010",
      mapping.ledger_account.code
    )
  end

  test "provisioning is idempotent" do
    service =
      Accounting::ProvisionDefaultChart.new(
        organization: @organization
      )

    service.call

    account_count =
      @organization
        .ledger_accounts
        .count

    mapping_count =
      @organization
        .accounting_account_mappings
        .count

    service.call

    assert_equal(
      account_count,
      @organization
        .ledger_accounts
        .count
    )

    assert_equal(
      mapping_count,
      @organization
        .accounting_account_mappings
        .count
    )
  end

  test "system accounts are protected mappings" do
    Accounting::ProvisionDefaultChart
      .new(
        organization: @organization
      )
      .call

    inventory =
      @organization
        .ledger_accounts
        .find_by!(
          code: "1200"
        )

    inventory.active =
      false

    assert_not inventory.valid?

    assert_includes(
      inventory.errors[:active],
      "cannot be disabled while used as a system account"
    )
  end
end
