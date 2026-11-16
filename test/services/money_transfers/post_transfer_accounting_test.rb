require "test_helper"

class MoneyTransfers::PostTransferAccountingTest <
  ActiveSupport::TestCase
  setup do
    @owner = create_user

    @organization =
      provision_organization_for(
        @owner
      )

    @source_ledger =
      @organization
        .ledger_accounts
        .create!(
          code: "1101",
          name: "Source Cash",
          account_type: "asset",
          normal_balance: "debit",
          report_group: "current_asset",
          active: true,
          postable: true
        )

    @destination_ledger =
      @organization
        .ledger_accounts
        .create!(
          code: "1102",
          name: "Destination Cash",
          account_type: "asset",
          normal_balance: "debit",
          report_group: "current_asset",
          active: true,
          postable: true
        )

    @source =
      create_money_account(
        organization:
          @organization,
        overrides: {
          name: "Source",
          opening_balance: 1_000,
          ledger_account:
            @source_ledger
        }
      )

    @destination =
      create_money_account(
        organization:
          @organization,
        overrides: {
          name: "Destination",
          opening_balance: 0,
          ledger_account:
            @destination_ledger
        }
      )

    @transfer =
      @organization
        .money_transfers
        .create!(
          recorded_by:
            @owner,
          from_money_account:
            @source,
          to_money_account:
            @destination,
          amount: 250,
          transferred_at:
            Time.current,
          reference:
            "TRF-001"
        )
  end

  test "creates a balanced journal entry" do
    assert_difference(
      "JournalEntry.count",
      1
    ) do
      MoneyTransfers::PostTransferAccounting.call(
        organization:
          @organization,
        transfer:
          @transfer
      )
    end

    journal =
      @organization
        .journal_entries
        .find_by!(
          source:
            @transfer
        )

    assert journal.status_posted?

    assert_equal 250.to_d,
                 journal.total_debits

    assert_equal 250.to_d,
                 journal.total_credits
  end

  test "debits destination and credits source" do
    journal =
      MoneyTransfers::PostTransferAccounting.call(
        organization:
          @organization,
        transfer:
          @transfer
      )

    debit_line =
      journal
        .journal_lines
        .find_by(
          ledger_account:
            @destination_ledger
        )

    credit_line =
      journal
        .journal_lines
        .find_by(
          ledger_account:
            @source_ledger
        )

    assert_equal 250.to_d,
                 debit_line.debit.to_d

    assert_equal 0.to_d,
                 debit_line.credit.to_d

    assert_equal 0.to_d,
                 credit_line.debit.to_d

    assert_equal 250.to_d,
                 credit_line.credit.to_d
  end

  test "posting is idempotent" do
    first =
      MoneyTransfers::PostTransferAccounting.call(
        organization:
          @organization,
        transfer:
          @transfer
      )

    assert_no_difference(
      "JournalEntry.count"
    ) do
      second =
        MoneyTransfers::PostTransferAccounting.call(
          organization:
            @organization,
          transfer:
            @transfer
        )

      assert_equal first.id,
                   second.id
    end
  end

  test "fails when source account has no ledger account" do
    @source.update!(
      ledger_account: nil
    )

    error =
      assert_raises(
        MoneyTransfers::TransferError
      ) do
        MoneyTransfers::PostTransferAccounting.call(
          organization:
            @organization,
          transfer:
            @transfer
        )
      end

    assert_match(
      /not linked to a ledger account/,
      error.message
    )
  end

  test "fails when destination account has no ledger account" do
    @destination.update!(
      ledger_account: nil
    )

    error =
      assert_raises(
        MoneyTransfers::TransferError
      ) do
        MoneyTransfers::PostTransferAccounting.call(
          organization:
            @organization,
          transfer:
            @transfer
        )
      end

    assert_match(
      /not linked to a ledger account/,
      error.message
    )
  end
end
