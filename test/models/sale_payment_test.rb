require "test_helper"

class SalePaymentTest < ActiveSupport::TestCase
  setup do
    @owner = create_user

    @organization =
      provision_organization_for(@owner)

    @branch = @organization.main_branch

    @sale =
      @organization.sales.create!(
        branch: @branch,
        cashier: @owner,
        sale_number: "TEST-000001",
        status: "completed",
        payment_status: "paid",
        sold_at: Time.current,
        subtotal: 100,
        discount_total: 0,
        tax_total: 0,
        total: 100,
        amount_paid: 100,
        balance_due: 0,
        change_given: 0
      )

    @payment_method =
      PaymentMethod.new(
        organization: @organization
      )

    @money_account =
      MoneyAccount.new(
        organization: @organization
      )
  end

  test "calculates change from tendered amount" do
    payment = build_payment(
      amount: 80,
      amount_tendered: 100
    )

    assert payment.valid?
    assert_equal 20.to_d,
                 payment.change_given
  end

  test "rejects tendered amount below payment" do
    payment = build_payment(
      amount: 100,
      amount_tendered: 80
    )

    assert_not payment.valid?

    assert_includes(
      payment.errors[:amount_tendered],
      "must cover the applied payment amount"
    )
  end

  test "rejects money account from another organization" do
    other_organization =
      provision_organization_for(create_user)

    foreign_account =
      MoneyAccount.new(
        organization: other_organization
      )

    payment = build_payment(
      money_account: foreign_account
    )

    assert_not payment.valid?

    assert_includes(
      payment.errors[:money_account],
      "must belong to the same organization"
    )
  end

  private

  def build_payment(overrides = {})
    defaults = {
      sale: @sale,
      payment_method: @payment_method,
      money_account: @money_account,
      recorded_by: @owner,
      amount: 100,
      amount_tendered: 100,
      paid_at: Time.current
    }

    @organization.sale_payments.new(
      defaults.merge(overrides)
    )
  end
end
