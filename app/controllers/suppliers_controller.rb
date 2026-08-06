class SuppliersController < ApplicationController
  before_action :authenticate_user!
  before_action :require_organization!
  before_action :require_supplier_management!

  before_action :set_supplier,
                only: %i[
                  show
                  edit
                  update
                  toggle_status
                ]

  def index
    @query =
      params[:q].to_s.strip

    @status =
      params[:status].presence_in(
        %w[active inactive all]
      ) || "active"

    @suppliers =
      current_organization
        .suppliers
        .order(:name)

    if @query.present?
      pattern =
        "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"

      @suppliers =
        @suppliers.where(
          <<~SQL.squish,
            suppliers.name ILIKE :pattern OR
            suppliers.phone ILIKE :pattern OR
            suppliers.email ILIKE :pattern OR
            suppliers.kra_pin ILIKE :pattern
          SQL
          pattern: pattern
        )
    end

    @suppliers =
      case @status
      when "active"
        @suppliers.where(active: true)
      when "inactive"
        @suppliers.where(active: false)
      else
        @suppliers
      end

    load_supplier_balances
  end

  def show
  end

  def new
    @supplier =
      current_organization.suppliers.new(
        active: true,
        payment_terms_days: 0
      )
  end

  def create
    @supplier =
      current_organization
        .suppliers
        .new(supplier_params)

    if @supplier.save
      redirect_to @supplier,
                  notice: "#{@supplier.name} was created."
    else
      render :new,
             status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @supplier.update(supplier_params)
      redirect_to @supplier,
                  notice: "#{@supplier.name} was updated."
    else
      render :edit,
             status: :unprocessable_entity
    end
  end

  def toggle_status
    @supplier.update!(active: !@supplier.active?)

    status =
      @supplier.active? ? "enabled" : "disabled"

    redirect_to suppliers_path,
                notice: "#{@supplier.name} was #{status}."
  end

  private

  def require_supplier_management!
    return if current_membership&.supplier_management?

    redirect_to dashboard_path,
                alert:
                  "Your role cannot manage suppliers."
  end

  def set_supplier
    @supplier =
      current_organization
        .suppliers
        .find(params[:id])
  end

  def supplier_params
    params.require(:supplier).permit(
      :name,
      :contact_person,
      :phone,
      :email,
      :kra_pin,
      :address,
      :notes,
      :payment_terms_days
    )
  end

  def load_supplier_balances
    supplier_ids =
      @suppliers.pluck(:id)

    if supplier_ids.empty?
      @supplier_outstanding = {}
      @supplier_overdue = {}
      return
    end

    purchases =
      current_organization
        .purchases
        .received
        .where(
          supplier_id: supplier_ids
        )

    @supplier_outstanding =
      purchases
        .group(:supplier_id)
        .sum(:balance_due)

    @supplier_overdue =
      purchases
        .where("balance_due > 0")
        .where("due_on < ?", Date.current)
        .group(:supplier_id)
        .sum(:balance_due)
  end
end
