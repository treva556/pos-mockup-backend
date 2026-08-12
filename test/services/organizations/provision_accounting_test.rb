require "test_helper"

class Organizations::ProvisionAccountingTest <
  ActiveSupport::TestCase
  test "new organization receives accounting foundation" do
    user =
      create_user

    organization =
      Organizations::Provision.call(
        user: user,
        organization_attributes: {
          name: "Provisioned Accounting Company",
          country_code: "KE",
          currency_code: "KES",
          time_zone: "Africa/Nairobi",
          active: true
        }
      )

    assert_equal(
      Accounting::ProvisionDefaultChart::ACCOUNTS.size,
      organization
        .ledger_accounts
        .count
    )

    assert_equal(
      Accounting::ProvisionDefaultChart::MAPPINGS.size,
      organization
        .accounting_account_mappings
        .count
    )

    assert_equal(
      "MAIN",
      organization.main_branch.code
    )

    owner_membership =
      organization
        .memberships
        .find_by!(
          user: user
        )

    assert_equal(
      "owner",
      owner_membership.role
    )

    sales_mapping =
      organization
        .accounting_account_mappings
        .find_by!(
          role: "sales_revenue"
        )

    assert_equal(
      "4010",
      sales_mapping
        .ledger_account
        .code
    )

    inventory_mapping =
      organization
        .accounting_account_mappings
        .find_by!(
          role: "inventory"
        )

    assert_equal(
      "1200",
      inventory_mapping
        .ledger_account
        .code
    )
  end
end
