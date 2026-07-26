require "test_helper"

class MoneyAccountTest < ActiveSupport::TestCase
  setup do
    @owner = create_user
    @organization = provision_organization_for(@owner)
    @branch = @organization.main_branch
  end

  test "normalizes account details" do
    account = create_money_account(
      organization: @organization,
      overrides: {
        name: "  Main Cash Till  ",
        account_number: "  abc 123  ",
        notes: "  Front office till  "
      }
    )

    assert_equal "Main Cash Till", account.name
    assert_equal "ABC 123", account.account_number
    assert_equal "Front office till", account.notes
  end

  test "requires a date for a non-zero opening balance" do
    account = @organization.money_accounts.new(
      name: "Undated Account",
      account_type: "cash",
      opening_balance: 500,
      opening_balance_date: nil,
      can_receive: true,
      can_pay: true
    )

    assert_not account.valid?

    assert_includes(
      account.errors[:opening_balance_date],
      "must be provided when an opening balance is entered"
    )
  end

  test "rejects a branch from another organization" do
    other_owner = create_user
    other_organization =
      provision_organization_for(other_owner)

    account = @organization.money_accounts.new(
      name: "Invalid Branch Account",
      branch: other_organization.main_branch,
      account_type: "cash",
      opening_balance: 0,
      can_receive: true,
      can_pay: true
    )

    assert_not account.valid?

    assert_includes(
      account.errors[:branch],
      "must belong to the same organization"
    )
  end

  test "calculates current balance from transfers" do
    source = create_money_account(
      organization: @organization,
      overrides: {
        name: "Source Account",
        opening_balance: 1_000
      }
    )

    destination = create_money_account(
      organization: @organization,
      overrides: {
        name: "Destination Account",
        opening_balance: 200
      }
    )

    create_money_transfer(
      organization: @organization,
      recorded_by: @owner,
      from_account: source,
      to_account: destination,
      overrides: {
        amount: 250
      }
    )

    assert_equal 750.to_d, source.current_balance
    assert_equal 450.to_d, destination.current_balance

    assert_equal 250.to_d,
                 source.outgoing_transfer_total

    assert_equal 250.to_d,
                 destination.incoming_transfer_total
  end
end
