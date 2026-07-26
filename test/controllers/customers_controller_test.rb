require "test_helper"

class CustomersControllerTest <
  ActionDispatch::IntegrationTest
  test "organization member can access customers" do
    user = create_user
    provision_organization_for(user)

    sign_in_as(user)

    get customers_path

    assert_response :success
  end

  test "user cannot access another organizations customer" do
    first_owner = create_user
    provision_organization_for(first_owner)

    second_owner = create_user
    second_organization =
      provision_organization_for(second_owner)

    foreign_customer =
      second_organization.customers.create!(
        name: "Foreign Customer",
        credit_limit: 0,
        payment_terms_days: 0
      )

    sign_in_as(first_owner)

    get customer_path(foreign_customer)

    assert_response :not_found
  end

  test "creating customer assigns current organization" do
    owner = create_user
    organization = provision_organization_for(owner)

    sign_in_as(owner)

    assert_difference("organization.customers.count", 1) do
      post customers_path,
           params: {
             customer: {
               name: "New Customer",
               phone: "0712345678",
               credit_limit: 0,
               payment_terms_days: 0
             }
           }
    end

    assert_equal(
      organization.id,
      Customer.order(:created_at).last.organization_id
    )
  end
end
