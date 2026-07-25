module Settings
  class OrganizationsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_organization!
    before_action :require_organization_admin!
    before_action :set_organization

    def edit
    end

    def update
      if @organization.update(organization_params)
        redirect_to edit_settings_organization_path,
                    notice: "Organization details were updated."
      else
        render :edit,
               status: :unprocessable_entity
      end
    end

    private

    def set_organization
      @organization = current_organization
    end

    def organization_params
      params.require(:organization).permit(
        :name,
        :legal_name,
        :registration_number,
        :kra_pin,
        :vat_registered,
        :phone,
        :email,
        :address,
        :country_code,
        :currency_code,
        :time_zone,
        :receipt_footer
      )
    end
  end
end