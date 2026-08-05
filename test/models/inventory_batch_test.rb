require "test_helper"

class InventoryBatchTest <
  ActiveSupport::TestCase
  setup do
    @owner = create_user

    @organization =
      provision_organization_for(@owner)

    @branch = @organization.main_branch

    @item =
      create_inventory_item(
        organization: @organization,
        overrides: {
          name: "Expiry Product",
          tracks_expiry: true
        }
      )
  end

  test "creates an expiry batch" do
    batch =
      @organization.inventory_batches.create!(
        branch: @branch,
        item: @item,
        batch_number: "BATCH-001",
        expires_on:
          30.days.from_now.to_date,
        quantity_received: 10,
        quantity_remaining: 10,
        unit_cost: 100,
        received_at: Time.current
      )

    assert batch.active?
    assert batch.sellable?
    refute batch.expired?
  end

  test "rejects batch for item without expiry tracking" do
    @item.update!(
      tracks_expiry: false
    )

    batch =
      @organization.inventory_batches.new(
        branch: @branch,
        item: @item,
        expires_on:
          30.days.from_now.to_date,
        quantity_received: 10,
        quantity_remaining: 10,
        unit_cost: 100,
        received_at: Time.current
      )

    refute batch.valid?

    assert_includes(
      batch.errors[:item],
      "must have expiry tracking enabled"
    )
  end

  test "marks empty batch as depleted" do
    batch =
      @organization.inventory_batches.create!(
        branch: @branch,
        item: @item,
        expires_on:
          30.days.from_now.to_date,
        quantity_received: 10,
        quantity_remaining: 0,
        unit_cost: 100,
        received_at: Time.current
      )

    assert batch.depleted?
  end
end
