require "test_helper"

module Organizations
  class ProvisionTest < ActiveSupport::TestCase
    test "creates organization main branch and owner membership" do
      user = create_user

      organization = nil

      assert_difference("Organization.count", 1) do
        assert_difference("Branch.count", 1) do
          assert_difference("Membership.count", 1) do
            organization =
              Organizations::Provision.call(
                user: user,
                organization_attributes: {
                  name: "Provisioned Business",
                  phone: "0700000000",
                  email: "business@example.com",
                  country_code: "KE",
                  currency_code: "KES",
                  time_zone: "Africa/Nairobi",
                  active: true
                }
              )
          end
        end
      end

      assert organization.persisted?

      main_branch = organization.main_branch

      assert_not_nil main_branch
      assert_equal "Main Branch", main_branch.name
      assert_equal "MAIN", main_branch.code
      assert main_branch.main?
      assert main_branch.active?

      membership =
        organization.memberships.find_by(user: user)

      assert_not_nil membership
      assert membership.owner?
      assert membership.active?
      assert_nil membership.branch
    end

    test "requires a user" do
      error = assert_raises(ArgumentError) do
        Organizations::Provision.call(
          user: nil,
          organization_attributes: {
            name: "No User Business",
            country_code: "KE",
            currency_code: "KES",
            time_zone: "Africa/Nairobi"
          }
        )
      end

      assert_equal "User is required", error.message
    end

    test "rolls back when organization is invalid" do
      user = create_user

      assert_no_difference(
        [
          "Organization.count",
          "Branch.count",
          "Membership.count"
        ]
      ) do
        assert_raises(ActiveRecord::RecordInvalid) do
          Organizations::Provision.call(
            user: user,
            organization_attributes: {
              name: "",
              country_code: "KE",
              currency_code: "KES",
              time_zone: "Africa/Nairobi"
            }
          )
        end
      end
    end
  end
end
