require "test_helper"

class PaymentMethodsControllerTest <
  ActionDispatch::IntegrationTest
  setup do
    @owner = create_user
    @organization = provision_organization_for(@owner)

    sign_in_as(@owner)
  end

  test "creates method in the current organization" do
    assert_difference("PaymentMethod.count", 1) do
      post payment_methods_path,
           params: {
             payment_method: {
               name: "Mobile Money",
               code: "MOBILE",
               payment_type: "mobile_money",
               requires_reference: "1"
             }
           }
    end

    method =
      @organization.payment_methods.order(:id).last

    assert_equal @organization, method.organization
    assert_redirected_to payment_method_path(method)
  end

  test "cannot access another organizations method" do
    other_organization =
      provision_organization_for(create_user)

    foreign_method = create_payment_method(
      organization: other_organization
    )

    get payment_method_path(foreign_method)

    assert_response :not_found
  end
end
