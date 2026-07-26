require "test_helper"

class MoneyTransfersControllerTest <
  ActionDispatch::IntegrationTest
  setup do
    @owner = create_user
    @organization = provision_organization_for(@owner)

    @source = create_money_account(
      organization: @organization,
      overrides: {
        name: "Source",
        opening_balance: 1_000
      }
    )

    @destination = create_money_account(
      organization: @organization,
      overrides: {
        name: "Destination",
        opening_balance: 0
      }
    )

    sign_in_as(@owner)
  end

  test "creates transfer for current organization and user" do
    assert_difference("MoneyTransfer.count", 1) do
      post money_transfers_path,
           params: {
             money_transfer: {
               from_money_account_id: @source.id,
               to_money_account_id: @destination.id,
               amount: 250,
               transferred_at: Time.current,
               reference: "TEST-TRANSFER"
             }
           }
    end

    transfer =
      @organization.money_transfers.order(:id).last

    assert_equal @owner, transfer.recorded_by
    assert_equal @organization, transfer.organization
    assert_equal 750.to_d, @source.current_balance
    assert_equal 250.to_d,
                 @destination.current_balance

    assert_redirected_to money_transfer_path(transfer)
  end

  test "cannot submit another organizations account" do
    other_organization =
      provision_organization_for(create_user)

    foreign_account = create_money_account(
      organization: other_organization
    )

    assert_no_difference("MoneyTransfer.count") do
      post money_transfers_path,
           params: {
             money_transfer: {
               from_money_account_id: @source.id,
               to_money_account_id: foreign_account.id,
               amount: 100,
               transferred_at: Time.current
             }
           }
    end

    assert_response :not_found
  end

  test "cannot access another organizations transfer" do
    other_owner = create_user
    other_organization =
      provision_organization_for(other_owner)

    foreign_source = create_money_account(
      organization: other_organization
    )

    foreign_destination = create_money_account(
      organization: other_organization
    )

    foreign_transfer = create_money_transfer(
      organization: other_organization,
      recorded_by: other_owner,
      from_account: foreign_source,
      to_account: foreign_destination
    )

    get money_transfer_path(foreign_transfer)

    assert_response :not_found
  end
end
