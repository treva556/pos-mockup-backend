class TaxRatesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_organization!
  before_action :require_product_setup_management!

  before_action :set_tax_rate,
                only: %i[edit update toggle_status]

  def index
    @status =
      params[:status].presence_in(
        %w[active inactive all]
      ) || "active"

    @tax_rates =
      current_organization
        .tax_rates
        .alphabetical

    @tax_rates =
      case @status
      when "inactive"
        @tax_rates.where(active: false)
      when "all"
        @tax_rates
      else
        @tax_rates.active
      end
  end

  def new
    @tax_rate =
      current_organization.tax_rates.new(
        active: true,
        rate: 0,
        tax_type: "standard"
      )
  end

  def create
    @tax_rate =
      current_organization
        .tax_rates
        .new(tax_rate_params)

    if @tax_rate.save
      redirect_to tax_rates_path,
                  notice: "#{@tax_rate.name} was created."
    else
      render :new,
             status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @tax_rate.update(tax_rate_params)
      redirect_to tax_rates_path,
                  notice: "#{@tax_rate.name} was updated."
    else
      render :edit,
             status: :unprocessable_entity
    end
  end

  def toggle_status
    @tax_rate.update!(
      active: !@tax_rate.active?
    )

    status = @tax_rate.active? ? "enabled" : "disabled"

    redirect_to tax_rates_path,
                notice: "#{@tax_rate.name} was #{status}."
  end

  private

  def require_product_setup_management!
    return if current_membership&.product_setup_management?

    redirect_to dashboard_path,
                alert:
                  "Your role cannot manage product setup."
  end

  def set_tax_rate
    @tax_rate =
      current_organization
        .tax_rates
        .find(params[:id])
  end

  def tax_rate_params
    params.require(:tax_rate).permit(
      :name,
      :code,
      :rate,
      :tax_type
    )
  end
end
