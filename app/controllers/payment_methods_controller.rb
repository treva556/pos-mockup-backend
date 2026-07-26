class PaymentMethodsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_organization!
  before_action :require_money_setup_management!

  before_action :set_payment_method,
                only: %i[
                  show
                  edit
                  update
                  toggle_status
                ]

  def index
    @query = params[:q].to_s.strip

    @status =
      params[:status].presence_in(
        %w[active inactive all]
      ) || "active"

    @payment_type =
      params[:payment_type].presence_in(
        PaymentMethod.payment_types.keys + [ "all" ]
      ) || "all"

    @payment_methods =
      current_organization
        .payment_methods
        .alphabetical

    @payment_methods =
      case @status
      when "inactive"
        @payment_methods.where(active: false)
      when "all"
        @payment_methods
      else
        @payment_methods.active
      end

    unless @payment_type == "all"
      @payment_methods =
        @payment_methods.where(
          payment_type: @payment_type
        )
    end

    return if @query.blank?

    pattern =
      "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"

    @payment_methods =
      @payment_methods.where(
        <<~SQL.squish,
          payment_methods.name ILIKE :pattern OR
          payment_methods.code ILIKE :pattern
        SQL
        pattern: pattern
      )
  end

  def show
  end

  def new
    @payment_method =
      current_organization.payment_methods.new(
        payment_type: "cash",
        requires_reference: false,
        active: true
      )
  end

  def create
    @payment_method =
      current_organization
        .payment_methods
        .new(payment_method_params)

    if @payment_method.save
      redirect_to @payment_method,
                  notice:
                    "#{@payment_method.name} was created."
    else
      render :new,
             status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @payment_method.update(payment_method_params)
      redirect_to @payment_method,
                  notice:
                    "#{@payment_method.name} was updated."
    else
      render :edit,
             status: :unprocessable_entity
    end
  end

  def toggle_status
    if disabling_used_payment_method?
      redirect_to payment_methods_path,
                  alert:
                    "Remove this method from active branch payment defaults before disabling it."

      return
    end

    @payment_method.update!(
      active: !@payment_method.active?
    )

    status =
      @payment_method.active? ? "enabled" : "disabled"

    redirect_to payment_methods_path,
                notice:
                  "#{@payment_method.name} was #{status}."
  end

  private

  def set_payment_method
    @payment_method =
      current_organization
        .payment_methods
        .find(params[:id])
  end

  def disabling_used_payment_method?
    @payment_method.active? &&
      @payment_method
        .branch_payment_settings
        .enabled
        .exists?
  end

  def payment_method_params
    params.require(:payment_method).permit(
      :name,
      :code,
      :payment_type,
      :requires_reference
    )
  end
end
