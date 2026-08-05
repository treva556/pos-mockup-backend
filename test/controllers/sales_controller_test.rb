require "test_helper"

class SalesControllerTest <
  ActionDispatch::IntegrationTest
  setup do
    @user = create_user

    @organization =
      provision_organization_for(@user)

    @main_branch =
      @organization.main_branch

    @second_branch =
      create_branch(
        organization: @organization,
        overrides: {
          name: "Second Branch"
        }
      )

    @main_sale =
      create_completed_sale(
        organization: @organization,
        branch: @main_branch,
        cashier: @user,
        sale_number: "MAIN-TEST-001"
      )

    @second_sale =
      create_completed_sale(
        organization: @organization,
        branch: @second_branch,
        cashier: @user,
        sale_number: "SECOND-TEST-001"
      )

    sign_in_as(@user)
  end

  test "owner can view sales from all branches" do
    get sales_path

    assert_response :success

    assert_includes response.body,
                    @main_sale.sale_number

    assert_includes response.body,
                    @second_sale.sale_number
  end

  test "owner can view a sale and its receipt" do
    get sale_path(@main_sale)

    assert_response :success

    assert_includes response.body,
                    @main_sale.sale_number

    get receipt_sale_path(@main_sale)

    assert_response :success

    assert_includes response.body,
                    @main_sale.sale_number
  end

  test "cashier only sees assigned branch sales" do
    membership =
      @organization
        .memberships
        .find_by!(user: @user)

    membership.update!(
      role: "cashier",
      branch: @main_branch
    )

    get sales_path

    assert_response :success

    assert_includes response.body,
                    @main_sale.sale_number

    refute_includes response.body,
                    @second_sale.sale_number
  end

  test "cashier cannot open another branch sale" do
    membership =
      @organization
        .memberships
        .find_by!(user: @user)

    membership.update!(
      role: "cashier",
      branch: @main_branch
    )

    get sale_path(@second_sale)

    assert_response :not_found

    get receipt_sale_path(@second_sale)

    assert_response :not_found
  end

  test "stock clerk cannot view sales" do
    membership =
      @organization
        .memberships
        .find_by!(user: @user)

    membership.update!(
      role: "stock_clerk",
      branch: @main_branch
    )

    get sales_path

    assert_redirected_to dashboard_path
  end

  test "cannot open a sale from another organization" do
    other_user = create_user

    other_organization =
      provision_organization_for(other_user)

    other_sale =
      create_completed_sale(
        organization: other_organization,
        branch: other_organization.main_branch,
        cashier: other_user,
        sale_number: "OTHER-ORG-001"
      )

    get sale_path(other_sale)

    assert_response :not_found

    get receipt_sale_path(other_sale)

    assert_response :not_found
  end

  private

  def create_completed_sale(
    organization:,
    branch:,
    cashier:,
    sale_number:
  )
    organization.sales.create!(
      branch: branch,
      cashier: cashier,
      sale_number: sale_number,
      status: "completed",
      payment_status: "paid",
      sold_at: Time.current,
      prices_include_tax: true,
      subtotal: 1_000,
      discount_total: 0,
      tax_total: 0,
      total: 1_000,
      amount_paid: 1_000,
      balance_due: 0,
      change_given: 0
    )
  end
end
