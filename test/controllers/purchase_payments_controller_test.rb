require "test_helper"

class PurchasePaymentsControllerTest <
  ActionDispatch::IntegrationTest
  setup do
    @owner = create_user

    @organization =
      provision_organization_for(@owner)

    @branch =
      @organization.main_branch

    @supplier =
      @organization.suppliers.create!(
        name: "Payment Test Supplier",
        active: true
      )

    @purchase =
      @organization.purchases.create!(
        branch: @branch,
        supplier: @supplier,
        recorded_by: @owner,
        purchase_number: "MAIN-PUR-PAY-001",
        status: "received",
        payment_status: "unpaid",
        purchased_on: Date.current,
        due_on: 30.days.from_now.to_date,
        received_at: Time.current,
        prices_include_tax: true,
        subtotal: 1_000,
        discount_total: 0,
        tax_total: 0,
        total: 1_000,
        amount_paid: 0,
        balance_due: 1_000
      )
  end

  test "owner opens supplier payment form" do
    sign_in_as(@owner)

    get new_purchase_payment_path(@purchase)

    assert_response :success
  end

  test "stock clerk cannot record supplier payments" do
    stock_clerk =
      create_user

    @organization.memberships.create!(
      user: stock_clerk,
      branch: @branch,
      role: "stock_clerk",
      active: true
    )

    sign_in_as(stock_clerk)

    get new_purchase_payment_path(@purchase)

    assert_redirected_to dashboard_path
  end

  test "cannot access another organizations purchase" do
    other_owner =
      create_user

    other_organization =
      provision_organization_for(other_owner)

    other_supplier =
      other_organization.suppliers.create!(
        name: "Other Payment Supplier",
        active: true
      )

    other_purchase =
      other_organization.purchases.create!(
        branch:
          other_organization.main_branch,
        supplier: other_supplier,
        recorded_by: other_owner,
        purchase_number: "OTHER-PAY-001",
        status: "received",
        payment_status: "unpaid",
        purchased_on: Date.current,
        due_on: 30.days.from_now.to_date,
        received_at: Time.current,
        prices_include_tax: true,
        subtotal: 1_000,
        discount_total: 0,
        tax_total: 0,
        total: 1_000,
        amount_paid: 0,
        balance_due: 1_000
      )

    sign_in_as(@owner)

    get new_purchase_payment_path(
      other_purchase
    )

    assert_response :not_found
  end
end
