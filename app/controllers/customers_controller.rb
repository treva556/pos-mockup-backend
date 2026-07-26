class CustomersController < ApplicationController
  before_action :authenticate_user!
  before_action :require_organization!

  before_action :set_customer,
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

    @customers =
      current_organization
        .customers
        .alphabetical

    @customers =
      case @status
      when "inactive"
        @customers.where(active: false)
      when "all"
        @customers
      else
        @customers.active
      end

    return if @query.blank?

    pattern =
      "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"

    @customers =
      @customers.where(
        <<~SQL.squish,
          customers.name ILIKE :pattern OR
          customers.phone ILIKE :pattern OR
          customers.email ILIKE :pattern OR
          customers.kra_pin ILIKE :pattern
        SQL
        pattern: pattern
      )
  end

  def show
  end

  def new
    @customer =
      current_organization.customers.new(
        active: true,
        credit_limit: 0,
        payment_terms_days: 0
      )
  end

  def create
    @customer =
      current_organization
        .customers
        .new(customer_params)

    if @customer.save
      redirect_to @customer,
                  notice: "#{@customer.name} was created."
    else
      render :new,
             status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @customer.update(customer_params)
      redirect_to @customer,
                  notice: "#{@customer.name} was updated."
    else
      render :edit,
             status: :unprocessable_entity
    end
  end

  def toggle_status
    @customer.update!(active: !@customer.active?)

    status =
      @customer.active? ? "enabled" : "disabled"

    redirect_to customers_path,
                notice: "#{@customer.name} was #{status}."
  end

  private

  def set_customer
    @customer =
      current_organization
        .customers
        .find(params[:id])
  end

  def customer_params
    params.require(:customer).permit(
      :name,
      :phone,
      :email,
      :kra_pin,
      :address,
      :notes,
      :credit_limit,
      :payment_terms_days
    )
  end
end
