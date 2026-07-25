require "test_helper"

class MembershipTest < ActiveSupport::TestCase
  test "owner has organization administrator access" do
    membership = Membership.create!(
      user: create_user,
      organization: create_organization,
      role: "owner",
      branch: nil,
      active: true
    )

    assert membership.organization_admin?
  end

  test "cashier must belong to a branch" do
    membership = Membership.new(
      user: create_user,
      organization: create_organization,
      role: "cashier",
      branch: nil,
      active: true
    )

    assert_not membership.valid?

    assert_includes(
      membership.errors[:branch],
      "must be selected for cashiers and stock clerks"
    )
  end

  test "owner cannot be restricted to one branch" do
    organization = create_organization
    branch = create_branch(organization: organization)

    membership = Membership.new(
      user: create_user,
      organization: organization,
      role: "owner",
      branch: branch,
      active: true
    )

    assert_not membership.valid?

    assert_includes(
      membership.errors[:branch],
      "must be blank for owners and administrators"
    )
  end

  test "branch must belong to the same organization" do
    organization = create_organization
    another_organization = create_organization

    foreign_branch =
      create_branch(organization: another_organization)

    membership = Membership.new(
      user: create_user,
      organization: organization,
      role: "cashier",
      branch: foreign_branch,
      active: true
    )

    assert_not membership.valid?

    assert_includes(
      membership.errors[:branch],
      "must belong to the same organization"
    )
  end
end
