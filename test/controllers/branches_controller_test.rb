require "test_helper"

class BranchesControllerTest < ActionDispatch::IntegrationTest
  test "owner cannot access another organizations branch" do
    first_owner = create_user
    provision_organization_for(first_owner)

    second_owner = create_user
    second_organization =
      provision_organization_for(second_owner)

    foreign_branch =
      second_organization.main_branch

    sign_in_as(first_owner)

    get edit_branch_path(foreign_branch)

    assert_response :not_found
  end

  test "branch restricted employee cannot switch branches" do
    owner = create_user
    organization = provision_organization_for(owner)

    second_branch = create_branch(
      organization: organization,
      overrides: {
        name: "Second Branch",
        code: "SECOND"
      }
    )

    cashier = create_user

    Membership.create!(
      user: cashier,
      organization: organization,
      branch: organization.main_branch,
      role: "cashier",
      active: true
    )

    sign_in_as(cashier)

    patch select_branch_path(second_branch)

    assert_redirected_to dashboard_path
  end
end
