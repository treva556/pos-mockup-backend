require "test_helper"

class MoneyTransfers::CreateTransferTest <
  ActiveSupport::TestCase
  setup do
    @owner = create_user

    @organization =
      provision_organization_for(
        @owner
      )

    @source =
      create_money_account(
        organization:
          @organization,
        overrides: {
          name: "Source",
          opening_balance: 1_000
        }
      )

    @destination =
      create_money_account(
        organization:
          @organization,
        overrides: {
          name: "Destination",
          opening_balance: 0
        }
      )
  end

  test "creates transfer and posts accounting" do
    accounting_called = false
    expected_organization = @organization

    singleton =
      class << MoneyTransfers::PostTransferAccounting
        self
      end

    singleton.alias_method(
      :original_call_for_create_test,
      :call
    )

    singleton.define_method(
      :call
    ) do |organization:, transfer:|
      accounting_called = true

      raise "Wrong organization" unless
        organization == expected_organization

      raise "Transfer was not persisted" unless
        transfer.persisted?

      Object.new
    end

    begin
      assert_difference(
        "MoneyTransfer.count",
        1
      ) do
        transfer =
          MoneyTransfers::CreateTransfer.call(
            organization:
              @organization,
            recorded_by:
              @owner,
            from_money_account:
              @source,
            to_money_account:
              @destination,
            attributes: {
              amount: 250,
              transferred_at:
                Time.current,
              reference:
                "TRF-001"
            }
          )

        assert transfer.persisted?
      end
    ensure
      singleton.alias_method(
        :call,
        :original_call_for_create_test
      )

      singleton.remove_method(
        :original_call_for_create_test
      )
    end

    assert accounting_called
  end

  test "rolls back transfer when accounting fails" do
    singleton =
      class << MoneyTransfers::PostTransferAccounting
        self
      end

    singleton.alias_method(
      :original_call_for_rollback_test,
      :call
    )

    singleton.define_method(
      :call
    ) do |**_arguments|
      raise MoneyTransfers::TransferError,
            "forced accounting failure"
    end

    begin
      assert_no_difference(
        "MoneyTransfer.count"
      ) do
        assert_raises(
          MoneyTransfers::TransferError
        ) do
          MoneyTransfers::CreateTransfer.call(
            organization:
              @organization,
            recorded_by:
              @owner,
            from_money_account:
              @source,
            to_money_account:
              @destination,
            attributes: {
              amount: 250,
              transferred_at:
                Time.current
            }
          )
        end
      end
    ensure
      singleton.alias_method(
        :call,
        :original_call_for_rollback_test
      )

      singleton.remove_method(
        :original_call_for_rollback_test
      )
    end

    assert_equal 1_000.to_d,
                 @source.current_balance

    assert_equal 0.to_d,
                 @destination.current_balance
  end
end
