require "test_helper"

class BranchTest < ActiveSupport::TestCase
  test "main branch cannot be disabled" do
    organization = create_organization

    branch = create_branch(
      organization: organization,
      overrides: {
        name: "Main Branch",
        code: "MAIN",
        main: true
      }
    )

    branch.active = false

    assert_not branch.valid?

    assert_includes(
      branch.errors[:active],
      "must remain enabled for the main branch"
    )
  end

  test "active branch with assigned members cannot be disabled" do
    organization = create_organization
    branch = create_branch(organization: organization)

    Membership.create!(
      user: create_user,
      organization: organization,
      branch: branch,
      role: "cashier",
      active: true
    )

    branch.active = false

    assert_not branch.valid?

    assert_includes(
      branch.errors[:active],
      "cannot be disabled while active team members are assigned"
    )
  end

  test "branch codes are unique within an organization" do
    organization = create_organization

    create_branch(
      organization: organization,
      overrides: { code: "CBD" }
    )

    duplicate = organization.branches.new(
      name: "Second CBD",
      code: "cbd",
      active: true
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:code], "has already been taken"
  end
end
