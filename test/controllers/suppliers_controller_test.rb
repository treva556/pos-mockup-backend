require "test_helper"

class SuppliersControllerTest <
  ActionDispatch::IntegrationTest
  test "owner can access suppliers" do
    owner = create_user
    provision_organization_for(owner)

    sign_in_as(owner)

    get suppliers_path

    assert_response :success
  end

  test "cashier cannot manage suppliers" do
    owner = create_user
    organization = provision_organization_for(owner)

    cashier = create_user

    Membership.create!(
      user: cashier,
      organization: organization,
      branch: organization.main_branch,
      role: "cashier",
      active: true
    )

    sign_in_as(cashier)

    get suppliers_path

    assert_redirected_to dashboard_path
  end

  test "user cannot access another organizations supplier" do
    first_owner = create_user
    provision_organization_for(first_owner)

    second_owner = create_user
    second_organization =
      provision_organization_for(second_owner)

    foreign_supplier =
      second_organization.suppliers.create!(
        name: "Foreign Supplier",
        payment_terms_days: 0
      )

    sign_in_as(first_owner)

    get supplier_path(foreign_supplier)

    assert_response :not_found
  end

  test "creating supplier assigns current organization" do
    owner = create_user
    organization = provision_organization_for(owner)

    sign_in_as(owner)

    assert_difference("organization.suppliers.count", 1) do
      post suppliers_path,
           params: {
             supplier: {
               name: "New Supplier",
               payment_terms_days: 30
             }
           }
    end

    assert_equal(
      organization.id,
      Supplier.order(:created_at).last.organization_id
    )
  end
end
