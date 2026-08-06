require "test_helper"

class PurchasesControllerTest <
  ActionDispatch::IntegrationTest
  setup do
    @owner = create_user

    @organization =
      provision_organization_for(@owner)

    @branch =
      @organization.main_branch

    @supplier =
      @organization.suppliers.create!(
        name: "Purchase History Supplier",
        active: true
      )

    @purchase =
      create_purchase(
        organization: @organization,
        branch: @branch,
        supplier: @supplier,
        recorded_by: @owner,
        number: "MAIN-PUR-000101"
      )
  end

  test "owner views purchase history" do
    sign_in_as(@owner)

    get purchases_path

    assert_response :success

    assert_includes(
      response.body,
      @purchase.purchase_number
    )
  end

  test "owner views purchase details and receipt" do
    sign_in_as(@owner)

    get purchase_path(@purchase)

    assert_response :success

    get receipt_purchase_path(@purchase)

    assert_response :success
  end

  test "cashier cannot view purchase records" do
    cashier =
      create_user

    @organization.memberships.create!(
      user: cashier,
      branch: @branch,
      role: "cashier",
      active: true
    )

    sign_in_as(cashier)

    get purchases_path

    assert_redirected_to dashboard_path
  end

  test "purchase from another organization is not accessible" do
    other_owner =
      create_user

    other_organization =
      provision_organization_for(other_owner)

    other_supplier =
      other_organization.suppliers.create!(
        name: "Other Supplier",
        active: true
      )

    other_purchase =
      create_purchase(
        organization: other_organization,
        branch:
          other_organization.main_branch,
        supplier: other_supplier,
        recorded_by: other_owner,
        number: "OTHER-PUR-000001"
      )

    sign_in_as(@owner)

    get purchase_path(other_purchase)

    assert_response :not_found
  end

  private

  def create_purchase(
    organization:,
    branch:,
    supplier:,
    recorded_by:,
    number:
  )
    organization.purchases.create!(
      branch: branch,
      supplier: supplier,
      recorded_by: recorded_by,
      purchase_number: number,
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
end
