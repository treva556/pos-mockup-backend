module TeamMembers
  class Create
    Result = Struct.new(
      :success?,
      :user,
      :membership,
      :errors,
      keyword_init: true
    )

    def self.call(
      organization:,
      user_attributes:,
      membership_attributes:
    )
      new(
        organization: organization,
        user_attributes: user_attributes,
        membership_attributes: membership_attributes
      ).call
    end

    def initialize(
      organization:,
      user_attributes:,
      membership_attributes:
    )
      @organization = organization
      @user_attributes = user_attributes
      @membership_attributes = membership_attributes
    end

    def call
      email =
        user_attributes
          .fetch(:email, "")
          .to_s
          .strip
          .downcase

      if User.exists?(email: email)
        return Result.new(
          success?: false,
          user: User.new(user_attributes),
          membership: organization.memberships.new(
            membership_attributes
          ),
          errors: [
            "That email already belongs to an account. " \
            "Existing-account invitations will be added later."
          ]
        )
      end

      user = User.new(
        user_attributes.merge(
          email: email,
          active: true,
          platform_role: "regular",
          must_change_password: true
        )
      )

      membership =
        organization.memberships.new(
          membership_attributes.merge(
            user: user,
            active: true
          )
        )

      ApplicationRecord.transaction do
        user.save!
        membership.save!
      end

      Result.new(
        success?: true,
        user: user,
        membership: membership,
        errors: []
      )
    rescue ActiveRecord::RecordInvalid
      errors =
        user.errors.full_messages +
        membership.errors.full_messages

      Result.new(
        success?: false,
        user: user,
        membership: membership,
        errors: errors.uniq
      )
    end

    private

    attr_reader :organization,
                :user_attributes,
                :membership_attributes
  end
end
