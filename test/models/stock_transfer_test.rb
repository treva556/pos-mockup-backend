require "test_helper"

class StockTransferTest < ActiveSupport::TestCase
  setup do
    @owner = create_user

    @organization =
      provision_organization_for(@owner)

    @from_branch = @organization.main_branch

    @to_branch =
      create_branch(organization: @organization)

    @item = create_inventory_item(
      organization: @organization
    )
  end

  test "source and destination branches must differ" do
    transfer = build_transfer(
      to_branch: @from_branch
    )

    assert_not transfer.valid?

    assert_includes(
      transfer.errors[:to_branch],
      "must be different from the source branch"
    )
  end

  test "rejects branch from another organization" do
    other_organization =
      provision_organization_for(create_user)

    transfer = build_transfer(
      to_branch: other_organization.main_branch
    )

    assert_not transfer.valid?

    assert_includes(
      transfer.errors[:to_branch],
      "must belong to the same organization"
    )
  end

  test "whole-number unit rejects decimal transfer" do
    transfer = build_transfer(quantity: 1.5)

    assert_not transfer.valid?

    assert_includes(
      transfer.errors[:quantity],
      "must be a whole number for this unit"
    )
  end

  private

  def build_transfer(
    to_branch: @to_branch,
    quantity: 2
  )
    @organization.stock_transfers.new(
      from_branch: @from_branch,
      to_branch: to_branch,
      item: @item,
      recorded_by: @owner,
      quantity: quantity,
      transferred_at: Time.current
    )
  end
end
