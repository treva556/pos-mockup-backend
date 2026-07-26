class UnitOfMeasuresController < ApplicationController
  before_action :authenticate_user!
  before_action :require_organization!
  before_action :require_product_setup_management!

  before_action :set_unit_of_measure,
                only: %i[edit update toggle_status]

  def index
    @status =
      params[:status].presence_in(
        %w[active inactive all]
      ) || "active"

    @unit_of_measures =
      current_organization
        .unit_of_measures
        .alphabetical

    @unit_of_measures =
      case @status
      when "inactive"
        @unit_of_measures.where(active: false)
      when "all"
        @unit_of_measures
      else
        @unit_of_measures.active
      end
  end

  def new
    @unit_of_measure =
      current_organization.unit_of_measures.new(
        active: true,
        decimal_allowed: false
      )
  end

  def create
    @unit_of_measure =
      current_organization
        .unit_of_measures
        .new(unit_of_measure_params)

    if @unit_of_measure.save
      redirect_to unit_of_measures_path,
                  notice:
                    "#{@unit_of_measure.name} was created."
    else
      render :new,
             status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @unit_of_measure.update(unit_of_measure_params)
      redirect_to unit_of_measures_path,
                  notice:
                    "#{@unit_of_measure.name} was updated."
    else
      render :edit,
             status: :unprocessable_entity
    end
  end

  def toggle_status
    @unit_of_measure.update!(
      active: !@unit_of_measure.active?
    )

    status =
      @unit_of_measure.active? ? "enabled" : "disabled"

    redirect_to unit_of_measures_path,
                notice:
                  "#{@unit_of_measure.name} was #{status}."
  end

  private

  def require_product_setup_management!
    return if current_membership&.product_setup_management?

    redirect_to dashboard_path,
                alert:
                  "Your role cannot manage product setup."
  end

  def set_unit_of_measure
    @unit_of_measure =
      current_organization
        .unit_of_measures
        .find(params[:id])
  end

  def unit_of_measure_params
    params.require(:unit_of_measure).permit(
      :name,
      :symbol,
      :decimal_allowed
    )
  end
end
