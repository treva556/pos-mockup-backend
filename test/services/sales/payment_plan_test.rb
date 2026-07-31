require "test_helper"

module Sales
  class PaymentPlanTest < ActiveSupport::TestCase
    setup do
      @owner = create_user

      @organization =
        provision_organization_for(@owner)

      @branch = @organization.main_branch

      @cash_method =
        create_payment_method(
          organization: @organization,
          overrides: {
            name: "Cash"
          }
        )

      @cash_account =
        create_money_account(
          organization: @organization,
          overrides: {
            name: "Main Cash Till"
          }
        )

      @mpesa_method =
        create_payment_method(
          organization: @organization,
          overrides: {
            name: "M-Pesa"
          }
        )

      @mpesa_account =
        create_money_account(
          organization: @organization,
          overrides: {
            name: "Main M-Pesa Till"
          }
        )

      @plan =
        Sales::PaymentPlan.new(
          organization: @organization,
          branch: @branch,
          sale_total: 5_000
        )
    end

    test "calculates cash change" do
      @plan.add_entry(
        payment_method_id: @cash_method.id,
        money_account_id: @cash_account.id,
        amount: 850,
        amount_tendered: 1_000
      )

      entry = @plan.entries.first

      assert_equal 850.to_d,
                   @plan.applied_total

      assert_equal 150.to_d,
                   entry.change_given

      assert_equal 4_150.to_d,
                   @plan.balance_due

      assert_equal "partially_paid",
                   @plan.payment_status
    end

    test "supports split payments" do
      @plan.add_entry(
        payment_method_id: @cash_method.id,
        money_account_id: @cash_account.id,
        amount: 2_000,
        amount_tendered: 2_000
      )

      @plan.add_entry(
        payment_method_id: @mpesa_method.id,
        money_account_id: @mpesa_account.id,
        amount: 3_000,
        amount_tendered: 3_000,
        reference: "ABC123XYZ"
      )

      assert_equal 2, @plan.entry_count
      assert_equal 5_000.to_d,
                   @plan.applied_total
      assert_equal 0.to_d,
                   @plan.balance_due
      assert_equal "paid",
                   @plan.payment_status
    end

    test "rejects payments above sale total" do
      @plan.add_entry(
        payment_method_id: @cash_method.id,
        money_account_id: @cash_account.id,
        amount: 2_000
      )

      assert_raises(
        Sales::InvalidPaymentError
      ) do
        @plan.add_entry(
          payment_method_id: @mpesa_method.id,
          money_account_id: @mpesa_account.id,
          amount: 3_500
        )
      end

      assert_equal 2_000.to_d,
                   @plan.applied_total

      assert_equal 1,
                   @plan.entry_count
    end

    test "rejects tendered amount below applied amount" do
      assert_raises(
        Sales::InvalidPaymentError
      ) do
        @plan.add_entry(
          payment_method_id: @cash_method.id,
          money_account_id: @cash_account.id,
          amount: 1_000,
          amount_tendered: 900
        )
      end

      assert @plan.empty?
    end

    test "round trips through session data" do
      @plan.add_entry(
        payment_method_id: @cash_method.id,
        money_account_id: @cash_account.id,
        amount: 2_000,
        amount_tendered: 2_500
      )

      restored =
        Sales::PaymentPlan.new(
          organization: @organization,
          branch: @branch,
          sale_total: 5_000,
          data: @plan.to_session
        )

      assert_equal 2_000.to_d,
                   restored.applied_total

      assert_equal 500.to_d,
                   restored.change_total

      assert_equal 3_000.to_d,
                   restored.balance_due
    end
  end
end
