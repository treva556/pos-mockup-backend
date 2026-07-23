module Organizations
  class Provision
    def self.call(user:, organization_attributes:)
      new(
        user: user,
        organization_attributes: organization_attributes
      ).call
    end

    def initialize(user:, organization_attributes:)
      @user = user
      @organization_attributes = organization_attributes
    end

    def call
      raise ArgumentError, "User is required" if user.blank?

      Organization.transaction do
        organization =
          Organization.create!(organization_attributes)

        organization.branches.create!(
          name: "Main Branch",
          code: "MAIN",
          main: true,
          active: true,
          phone: organization.phone,
          email: organization.email
        )

        organization.memberships.create!(
          user: user,
          role: "owner",
          active: true,
          branch: nil
        )

        organization
      end
    end

    private

    attr_reader :user, :organization_attributes
  end
end