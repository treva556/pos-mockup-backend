require "test_helper"

class CustomerAccountsControllerTest <
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
          name: "Credit Branch"
        }
      )

    @customer =
      @organization.customers.create!(
        name: "Account Customer",
        active: true
      )

    @main_sale =
      create_credit_sale(
        branch: @main_branch,
        sale_number: "CREDIT-MAIN-001"
      )

    @second_sale =
      create_credit_sale(
        branch: @second_branch,
        sale_number: "CREDIT-SECOND-001"
      )

    sign_in_as(@user)
  end

  test "owner can view customer account" do
    get customer_account_path(@customer)

    assert_response :success

    assert_includes response.body,
                    @main_sale.sale_number

    assert_includes response.body,
                    @second_sale.sale_number
  end

  test "cashier only sees assigned branch customer sales" do
    membership =
      @organization
        .memberships
        .find_by!(user: @user)

    membership.update!(
      role: "cashier",
      branch: @main_branch
    )

    get customer_account_path(@customer)

    assert_response :success

    assert_includes response.body,
                    @main_sale.sale_number

    refute_includes response.body,
                    @second_sale.sale_number
  end

  test "stock clerk cannot view customer accounts" do
    membership =
      @organization
        .memberships
        .find_by!(user: @user)

    membership.update!(
      role: "stock_clerk",
      branch: @main_branch
    )

    get customer_account_path(@customer)

    assert_redirected_to dashboard_path
  end

  test "cannot view another organization customer account" do
    other_user = create_user

    other_organization =
      provision_organization_for(other_user)

    other_customer =
      other_organization.customers.create!(
        name: "Other Organization Customer",
        active: true
      )

    get customer_account_path(other_customer)

    assert_response :not_found
  end

  private

  def create_credit_sale(
    branch:,
    sale_number:
  )
    @organization.sales.create!(
      branch: branch,
      customer: @customer,
      cashier: @user,
      sale_number: sale_number,
      status: "completed",
      payment_status: "unpaid",
      sold_at: Time.current,
      due_on: 30.days.from_now.to_date,
      prices_include_tax: true,
      subtotal: 1_000,
      discount_total: 0,
      tax_total: 0,
      total: 1_000,
      amount_paid: 0,
      balance_due: 1_000,
      change_given: 0
    )
  end
end
