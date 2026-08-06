require "test_helper"

class StockLevelTest < ActiveSupport::TestCase
  test "uses unexpired batch quantity for expiry tracked products" do
    owner = create_user

    organization =
      provision_organization_for(owner)

    branch =
      organization.main_branch

    item =
      create_inventory_item(
        organization: organization,
        overrides: {
          tracks_expiry: true
        }
      )

    stock_level =
      organization.stock_levels.find_or_initialize_by(
        branch: branch,
        item: item
      )

    stock_level.update!(
      quantity_on_hand: 15,
      reorder_level: 10
    )

    organization.inventory_batches.create!(
      branch: branch,
      item: item,
      batch_number: "EXPIRED-BATCH",
      expires_on:
        2.days.ago.to_date,
      quantity_received: 10,
      quantity_remaining: 10,
      unit_cost: 100,
      received_at: Time.current
    )

    organization.inventory_batches.create!(
      branch: branch,
      item: item,
      batch_number: "ACTIVE-BATCH",
      expires_on:
        30.days.from_now.to_date,
      quantity_received: 5,
      quantity_remaining: 5,
      unit_cost: 100,
      received_at: Time.current
    )

    assert_equal 15.to_d,
                 stock_level.quantity_on_hand

    assert_equal 5.to_d,
                 stock_level.sellable_quantity

    assert_equal 10.to_d,
                 stock_level.expired_quantity

    assert_equal 15.to_d,
                 stock_level.assigned_batch_quantity

    assert_equal 0.to_d,
                 stock_level.unassigned_expiry_quantity

    assert stock_level.low_sellable_stock?

    refute stock_level.out_of_sellable_stock?
  end

  test "normal products use physical quantity as sellable quantity" do
    owner = create_user

    organization =
      provision_organization_for(owner)

    branch =
      organization.main_branch

    item =
      create_inventory_item(
        organization: organization,
        overrides: {
          tracks_expiry: false
        }
      )

    stock_level =
      organization.stock_levels.find_or_initialize_by(
        branch: branch,
        item: item
      )

    stock_level.update!(
      quantity_on_hand: 8,
      reorder_level: 10
    )

    assert_equal 8.to_d,
                 stock_level.quantity_on_hand

    assert_equal 8.to_d,
                 stock_level.sellable_quantity

    assert_equal 0.to_d,
                 stock_level.expired_quantity

    assert_equal 0.to_d,
                 stock_level.unassigned_expiry_quantity

    assert stock_level.low_sellable_stock?

    refute stock_level.out_of_sellable_stock?
  end

  test "expiry tracked product with only expired stock is out of sellable stock" do
    owner = create_user

    organization =
      provision_organization_for(owner)

    branch =
      organization.main_branch

    item =
      create_inventory_item(
        organization: organization,
        overrides: {
          tracks_expiry: true
        }
      )

    stock_level =
      organization.stock_levels.find_or_initialize_by(
        branch: branch,
        item: item
      )

    stock_level.update!(
      quantity_on_hand: 6,
      reorder_level: 3
    )

    organization.inventory_batches.create!(
      branch: branch,
      item: item,
      batch_number: "EXPIRED-ONLY",
      expires_on:
        1.day.ago.to_date,
      quantity_received: 6,
      quantity_remaining: 6,
      unit_cost: 100,
      received_at: Time.current
    )

    assert_equal 6.to_d,
                 stock_level.quantity_on_hand

    assert_equal 0.to_d,
                 stock_level.sellable_quantity

    assert_equal 6.to_d,
                 stock_level.expired_quantity

    assert stock_level.out_of_sellable_stock?

    refute stock_level.low_sellable_stock?
  end

  test "reports expiry tracked stock without a batch as unassigned" do
    owner = create_user

    organization =
      provision_organization_for(owner)

    branch =
      organization.main_branch

    item =
      create_inventory_item(
        organization: organization,
        overrides: {
          tracks_expiry: true
        }
      )

    stock_level =
      organization.stock_levels.find_or_initialize_by(
        branch: branch,
        item: item
      )

    stock_level.update!(
      quantity_on_hand: 12,
      reorder_level: 5
    )

    assert_equal 12.to_d,
                 stock_level.quantity_on_hand

    assert_equal 0.to_d,
                 stock_level.sellable_quantity

    assert_equal 0.to_d,
                 stock_level.expired_quantity

    assert_equal 12.to_d,
                 stock_level.unassigned_expiry_quantity

    assert stock_level.out_of_sellable_stock?
  end
end
