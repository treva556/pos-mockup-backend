require "test_helper"

class InventoryControllersTest <
  ActionDispatch::IntegrationTest
  setup do
    @owner = create_user

    @organization =
      provision_organization_for(@owner)

    @branch = @organization.main_branch

    @second_branch =
      create_branch(organization: @organization)

    @item = create_inventory_item(
      organization: @organization
    )

    Inventory::PostMovement.call(
      organization: @organization,
      branch: @branch,
      item: @item,
      recorded_by: @owner,
      movement_type: "opening",
      quantity_change: 10
    )
  end

  test "owner records an inventory adjustment" do
    sign_in_as(@owner)

    assert_difference("StockMovement.count", 1) do
      post inventory_adjustments_path,
           params: {
             inventory_adjustment: {
               branch_id: @branch.id,
               item_id: @item.id,
               movement_type: "adjustment_out",
               quantity: 2,
               occurred_at: Time.current,
               reference: "COUNT-001",
               notes: "Stock count correction"
             }
           }
    end

    level =
      @organization.stock_levels.find_by!(
        branch: @branch,
        item: @item
      )

    assert_equal 8.to_d, level.quantity_on_hand
  end

  test "owner updates reorder level" do
    sign_in_as(@owner)

    patch update_reorder_level_stock_levels_path,
          params: {
            branch_id: @branch.id,
            item_id: @item.id,
            reorder_level: 3
          }

    level =
      @organization.stock_levels.find_by!(
        branch: @branch,
        item: @item
      )

    assert_equal 3.to_d, level.reorder_level

    assert_redirected_to stock_levels_path(
      branch_id: @branch.id
    )
  end

  test "owner creates branch stock transfer" do
    sign_in_as(@owner)

    assert_difference("StockTransfer.count", 1) do
      assert_difference("StockMovement.count", 2) do
        post stock_transfers_path,
             params: {
               stock_transfer: {
                 from_branch_id: @branch.id,
                 to_branch_id: @second_branch.id,
                 item_id: @item.id,
                 quantity: 4,
                 transferred_at: Time.current,
                 reference: "BRANCH-TRANSFER"
               }
             }
      end
    end

    source =
      @organization.stock_levels.find_by!(
        branch: @branch,
        item: @item
      )

    destination =
      @organization.stock_levels.find_by!(
        branch: @second_branch,
        item: @item
      )

    assert_equal 6.to_d, source.quantity_on_hand
    assert_equal 4.to_d, destination.quantity_on_hand
  end

  test "cashier can view inventory but cannot change it" do
    cashier = create_user

    Membership.create!(
      user: cashier,
      organization: @organization,
      branch: @branch,
      role: "cashier",
      active: true
    )

    sign_in_as(cashier)

    get stock_levels_path(branch_id: @branch.id)
    assert_response :success

    get stock_movements_path
    assert_response :success

    get new_inventory_adjustment_path
    assert_redirected_to dashboard_path

    get new_stock_transfer_path
    assert_redirected_to dashboard_path

    patch update_reorder_level_stock_levels_path,
          params: {
            branch_id: @branch.id,
            item_id: @item.id,
            reorder_level: 5
          }

    assert_redirected_to dashboard_path
  end

  test "cannot view another organizations inventory records" do
    other_owner = create_user

    other_organization =
      provision_organization_for(other_owner)

    foreign_item = create_inventory_item(
      organization: other_organization
    )

    Inventory::PostMovement.call(
      organization: other_organization,
      branch: other_organization.main_branch,
      item: foreign_item,
      recorded_by: other_owner,
      movement_type: "opening",
      quantity_change: 5
    )

    foreign_movement =
      other_organization.stock_movements.last

    sign_in_as(@owner)

    get stock_levels_path(
      branch_id: other_organization.main_branch.id
    )

    assert_response :not_found

    get stock_movement_path(foreign_movement)

    assert_response :not_found
  end
end
