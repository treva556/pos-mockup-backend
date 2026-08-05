require "test_helper"

class SalePaymentsControllerTest <
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
          name: "Second Credit Branch"
        }
      )

    @customer =
      @organization.customers.create!(
        name: "Payment Customer",
        active: true
      )

    @main_sale =
      create_credit_sale(
        branch: @main_branch,
        sale_number: "PAY-MAIN-001"
      )

    @second_sale =
      create_credit_sale(
        branch: @second_branch,
        sale_number: "PAY-SECOND-001"
      )

    sign_in_as(@user)
  end

  test "authorized user can open payment form" do
    get new_sale_payment_path(@main_sale)

    assert_response :success

    assert_includes response.body,
                    @main_sale.sale_number
  end

  test "cashier cannot receive payment for another branch" do
    membership =
      @organization
        .memberships
        .find_by!(user: @user)

    membership.update!(
      role: "cashier",
      branch: @main_branch
    )

    get new_sale_payment_path(@second_sale)

    assert_response :not_found
  end

  test "stock clerk cannot open payment form" do
    membership =
      @organization
        .memberships
        .find_by!(user: @user)

    membership.update!(
      role: "stock_clerk",
      branch: @main_branch
    )

    get new_sale_payment_path(@main_sale)

    assert_redirected_to dashboard_path
  end

  test "cannot receive payment for another organization sale" do
    other_user = create_user

    other_organization =
      provision_organization_for(other_user)

    other_customer =
      other_organization.customers.create!(
        name: "Other Credit Customer",
        active: true
      )

    other_sale =
      other_organization.sales.create!(
        branch: other_organization.main_branch,
        customer: other_customer,
        cashier: other_user,
        sale_number: "OTHER-PAY-001",
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

    get new_sale_payment_path(other_sale)

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
