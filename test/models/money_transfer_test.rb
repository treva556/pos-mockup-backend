require "test_helper"

class MoneyTransferTest < ActiveSupport::TestCase
  setup do
    @owner = create_user
    @organization = provision_organization_for(@owner)

    @source = create_money_account(
      organization: @organization,
      overrides: {
        name: "Source Account",
        opening_balance: 1_000
      }
    )

    @destination = create_money_account(
      organization: @organization,
      overrides: {
        name: "Destination Account",
        opening_balance: 0
      }
    )
  end

  test "records a valid transfer" do
    transfer = create_money_transfer(
      organization: @organization,
      recorded_by: @owner,
      from_account: @source,
      to_account: @destination,
      overrides: {
        amount: 300
      }
    )

    assert transfer.persisted?
    assert_equal 700.to_d, @source.current_balance
    assert_equal 300.to_d, @destination.current_balance
  end

  test "source and destination must differ" do
    transfer = @organization.money_transfers.new(
      from_money_account: @source,
      to_money_account: @source,
      recorded_by: @owner,
      amount: 100,
      transferred_at: Time.current
    )

    assert_not transfer.valid?

    assert_includes(
      transfer.errors[:to_money_account],
      "must be different from the source account"
    )
  end

  test "amount cannot exceed source balance" do
    transfer = @organization.money_transfers.new(
      from_money_account: @source,
      to_money_account: @destination,
      recorded_by: @owner,
      amount: 1_500,
      transferred_at: Time.current
    )

    assert_not transfer.valid?

    assert_includes(
      transfer.errors[:amount],
      "cannot exceed the source account balance"
    )
  end

  test "rejects an account from another organization" do
    other_organization =
      provision_organization_for(create_user)

    foreign_account = create_money_account(
      organization: other_organization
    )

    transfer = @organization.money_transfers.new(
      from_money_account: @source,
      to_money_account: foreign_account,
      recorded_by: @owner,
      amount: 100,
      transferred_at: Time.current
    )

    assert_not transfer.valid?

    assert_includes(
      transfer.errors[:to_money_account],
      "must belong to the same organization"
    )
  end

  test "source account must allow payments" do
    @source.update!(can_pay: false)

    transfer = @organization.money_transfers.new(
      from_money_account: @source,
      to_money_account: @destination,
      recorded_by: @owner,
      amount: 100,
      transferred_at: Time.current
    )

    assert_not transfer.valid?

    assert_includes(
      transfer.errors[:from_money_account],
      "must be able to make payments"
    )
  end

  test "destination account must receive money" do
    @destination.update!(can_receive: false)

    transfer = @organization.money_transfers.new(
      from_money_account: @source,
      to_money_account: @destination,
      recorded_by: @owner,
      amount: 100,
      transferred_at: Time.current
    )

    assert_not transfer.valid?

    assert_includes(
      transfer.errors[:to_money_account],
      "must be able to receive money"
    )
  end
end
