require "test_helper"

class Sales::PostSaleInventoryAccountingTest <
  ActiveSupport::TestCase
  setup do
    @owner =
      create_user

    @organization =
      provision_organization_for(
        @owner
      )

    @organization.update!(
      accounting_enabled: true
    )

    @branch =
      @organization.main_branch

    @cash_method =
      create_payment_method(
        organization: @organization,
        overrides: {
          name:
            "COGS Test Cash"
        }
      )

    @cash_ledger =
      @organization
        .ledger_accounts
        .create!(
          code: "1018",
          name: "COGS Test Cash",
          account_type: "asset",
          normal_balance: "debit",
          report_group: "current_asset",
          postable: true,
          active: true,
          system_account: false
        )

    @cash_account =
      create_money_account(
        organization: @organization,
        overrides: {
          name:
            "COGS Test Till"
        }
      )

    @cash_account.update!(
      ledger_account:
        @cash_ledger
    )
  end

  test "normal stock uses sale line cost snapshot" do
    item =
      create_inventory_item(
        organization: @organization,
        overrides: {
          name: "Normal Cost Item",
          selling_price: 500,
          purchase_cost: 300
        }
      )

    Inventory::PostMovement.call(
      organization: @organization,
      branch: @branch,
      item: item,
      recorded_by: @owner,
      movement_type: "opening",
      quantity_change: 10
    )

    sale =
      complete_paid_sale(
        item: item,
        quantity: 2
      )

    journal =
      @organization
        .journal_entries
        .find_by!(
          source: sale
        )

    assert_cost_lines(
      journal: journal,
      cost: 600
    )

    assert journal.balanced?
  end

  test "expiry stock uses exact FEFO batch costs" do
    item =
      create_inventory_item(
        organization: @organization,
        overrides: {
          name: "Batch Cost Item",
          selling_price: 500,
          purchase_cost: 999,
          tracks_expiry: true
        }
      )

    create_batch(
      item: item,
      number: "COST-A",
      expires_on:
        10.days.from_now.to_date,
      quantity: 1,
      unit_cost: 100
    )

    create_batch(
      item: item,
      number: "COST-B",
      expires_on:
        30.days.from_now.to_date,
      quantity: 5,
      unit_cost: 150
    )

    sale =
      complete_paid_sale(
        item: item,
        quantity: 2
      )

    journal =
      @organization
        .journal_entries
        .find_by!(
          source: sale
        )

    # FEFO:
    # 1 x 100 from COST-A
    # 1 x 150 from COST-B
    # total COGS = 250
    assert_cost_lines(
      journal: journal,
      cost: 250
    )

    assert_not_equal(
      1_998.to_d,
      mapped_account_line(
        journal: journal,
        role: "cost_of_goods_sold"
      ).debit
    )

    assert journal.balanced?
  end

  private

  def complete_paid_sale(
    item:,
    quantity:
  )
    cart =
      Sales::Cart.new(
        organization: @organization,
        branch: @branch
      )

    cart.add_item(
      item: item,
      quantity: quantity
    )

    plan =
      Sales::PaymentPlan.new(
        organization: @organization,
        branch: @branch,
        sale_total:
          cart.calculation.total
      )

    plan.add_entry(
      payment_method_id:
        @cash_method.id,
      money_account_id:
        @cash_account.id,
      amount:
        cart.calculation.total
    )

    Sales::CompleteSale.call(
      organization: @organization,
      branch: @branch,
      cashier: @owner,
      cart: cart,
      payment_plan: plan
    )
  end

  def create_batch(
    item:,
    number:,
    expires_on:,
    quantity:,
    unit_cost:
  )
    batch =
      @organization
        .inventory_batches
        .create!(
          branch: @branch,
          item: item,
          batch_number: number,
          expires_on: expires_on,
          quantity_received:
            quantity,
          quantity_remaining:
            quantity,
          unit_cost: unit_cost,
          received_at:
            Time.current
        )

    Inventory::PostMovement.call(
      organization: @organization,
      branch: @branch,
      item: item,
      recorded_by: @owner,
      movement_type: "purchase",
      quantity_change:
        quantity,
      inventory_batch:
        batch
    )

    batch
  end

  def assert_cost_lines(
    journal:,
    cost:
  )
    cogs =
      mapped_account_line(
        journal: journal,
        role:
          "cost_of_goods_sold"
      )

    inventory =
      mapped_account_line(
        journal: journal,
        role: "inventory"
      )

    assert_equal(
      cost.to_d,
      cogs.debit
    )

    assert_equal(
      0.to_d,
      cogs.credit
    )

    assert_equal(
      0.to_d,
      inventory.debit
    )

    assert_equal(
      cost.to_d,
      inventory.credit
    )
  end

  def mapped_account_line(
    journal:,
    role:
  )
    account =
      @organization
        .accounting_account_mappings
        .find_by!(
          role: role
        )
        .ledger_account

    journal
      .journal_lines
      .find_by!(
        ledger_account:
          account
      )
  end
end
