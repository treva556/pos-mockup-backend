require "test_helper"

class Accounting::AutomatedPostingRegressionTest <
  ActiveSupport::TestCase
  setup do
    @user =
      create_user

    @organization =
      provision_organization_for(
        @user
      )

    @organization.update!(
      accounting_enabled: true
    )

    @branch =
      @organization.main_branch
  end

  test "all posted journals remain individually balanced" do
    create_sample_postings

    journals =
      @organization
        .journal_entries
        .where(
          status: "posted"
        )

    assert journals.any?

    journals.each do |journal|
      assert(
        journal.balanced?,
        "#{journal.entry_number} is not balanced"
      )

      assert_equal(
        journal.total_debits,
        journal.total_credits,
        "#{journal.entry_number} debit and credit totals differ"
      )
    end
  end

  test "organization wide posted debits equal posted credits" do
    create_sample_postings

    lines =
      JournalLine
        .joins(:journal_entry)
        .where(
          organization:
            @organization,
          journal_entries: {
            status: "posted"
          }
        )

    total_debits =
      lines.sum(:debit).to_d

    total_credits =
      lines.sum(:credit).to_d

    assert total_debits.positive?

    assert_equal(
      total_debits,
      total_credits
    )
  end

  test "money transfer operational movement matches ledger movement" do
    source_ledger =
      create_money_ledger(
        code: "1017",
        name: "Regression Source Cash"
      )

    destination_ledger =
      create_money_ledger(
        code: "1018",
        name: "Regression Destination Cash"
      )

    source =
      create_money_account(
        organization:
          @organization,
        overrides: {
          name:
            "Regression Source",
          opening_balance:
            1_000,
          ledger_account:
            source_ledger
        }
      )

    destination =
      create_money_account(
        organization:
          @organization,
        overrides: {
          name:
            "Regression Destination",
          opening_balance:
            0,
          ledger_account:
            destination_ledger
        }
      )

    source_before =
      source.current_balance

    destination_before =
      destination.current_balance

    transfer =
      MoneyTransfers::CreateTransfer.call(
        organization:
          @organization,
        recorded_by:
          @user,
        from_money_account:
          source,
        to_money_account:
          destination,
        attributes: {
          amount: 250,
          transferred_at:
            Time.current,
          reference:
            "REG-TRANSFER"
        }
      )

    assert_equal(
      250.to_d,
      source_before -
        source.reload.current_balance
    )

    assert_equal(
      250.to_d,
      destination.reload.current_balance -
        destination_before
    )

    journal =
      @organization
        .journal_entries
        .find_by!(
          source: transfer
        )

    source_line =
      journal
        .journal_lines
        .find_by!(
          ledger_account:
            source_ledger
        )

    destination_line =
      journal
        .journal_lines
        .find_by!(
          ledger_account:
            destination_ledger
        )

    assert_equal 250.to_d,
                 source_line.credit.to_d

    assert_equal 0.to_d,
                 source_line.debit.to_d

    assert_equal 250.to_d,
                 destination_line.debit.to_d

    assert_equal 0.to_d,
                 destination_line.credit.to_d
  end

  private

  def create_sample_postings
    source_ledger =
      create_money_ledger(
        code: "1019",
        name: "Regression Cash A"
      )

    destination_ledger =
      create_money_ledger(
        code: "1021",
        name: "Regression Cash B"
      )

    source =
      create_money_account(
        organization:
          @organization,
        overrides: {
          name:
            "Regression Cash A",
          opening_balance:
            2_000,
          ledger_account:
            source_ledger
        }
      )

    destination =
      create_money_account(
        organization:
          @organization,
        overrides: {
          name:
            "Regression Cash B",
          opening_balance:
            0,
          ledger_account:
            destination_ledger
        }
      )

    MoneyTransfers::CreateTransfer.call(
      organization:
        @organization,
      recorded_by:
        @user,
      from_money_account:
        source,
      to_money_account:
        destination,
      attributes: {
        amount: 500,
        transferred_at:
          Time.current,
        reference:
          "REG-001"
      }
    )

    receivable =
      @organization
        .ledger_accounts
        .find_by!(
          code: "1100"
        )

    revenue =
      @organization
        .ledger_accounts
        .find_by!(
          code: "4010"
        )

    Accounting::CreateJournalEntry.call(
      organization:
        @organization,
      created_by:
        @user,
      entry_date:
        Date.current,
      description:
        "Regression balanced posting",
      lines: [
        {
          ledger_account:
            receivable,
          branch:
            @branch,
          debit: 1_000,
          credit: 0
        },
        {
          ledger_account:
            revenue,
          branch:
            @branch,
          debit: 0,
          credit: 1_000
        }
      ]
    )
  end

  def create_money_ledger(
    code:,
    name:
  )
    @organization
      .ledger_accounts
      .create!(
        code: code,
        name: name,
        account_type: "asset",
        normal_balance: "debit",
        report_group: "current_asset",
        postable: true,
        active: true,
        system_account: false
      )
  end
end
