module Onboarding
  class OrganizationsController < ApplicationController
    before_action :authenticate_user!
    before_action :redirect_existing_organization

    def new
      @organization = Organization.new(
        country_code: "KE",
        currency_code: "KES",
        time_zone: "Africa/Nairobi"
      )
    end

    def create
      @organization =
        Organization.new(organization_params)

      organization =
        Organizations::Provision.call(
          user: current_user,
          organization_attributes:
            organization_params.to_h.symbolize_keys
        )

      session[:organization_id] = organization.id

      redirect_to dashboard_path,
                  notice: "#{organization.name} is ready."
    rescue ActiveRecord::RecordInvalid => error
      copy_validation_errors(error.record)

      render :new, status: :unprocessable_entity
    end

    private

    def organization_params
      params.require(:organization).permit(
        :name,
        :legal_name,
        :phone,
        :email,
        :country_code,
        :currency_code,
        :time_zone
      )
    end

    def redirect_existing_organization
      return unless current_user.memberships.active.exists?

      redirect_to dashboard_path,
                  notice: "Your organization is already configured."
    end

    def copy_validation_errors(record)
      if record.is_a?(Organization)
        @organization = record
      else
        record.errors.full_messages.each do |message|
          @organization.errors.add(:base, message)
        end
      end
    end
  end
end