class ItemsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_organization!
  before_action :require_product_setup_management!

  before_action :set_item,
                only: %i[
                  show
                  edit
                  update
                  toggle_status
                ]

  before_action :load_form_options,
                only: %i[new create edit update]

  def index
    @query = params[:q].to_s.strip

    @status =
      params[:status].presence_in(
        %w[active inactive all]
      ) || "active"

    @item_type =
      params[:item_type].presence_in(
        %w[product service all]
      ) || "all"

    @items =
      current_organization
        .items
        .includes(
          :product_category,
          :unit_of_measure,
          :tax_rate
        )
        .alphabetical

    @items =
      case @status
      when "inactive"
        @items.where(active: false)
      when "all"
        @items
      else
        @items.active
      end

    unless @item_type == "all"
      @items =
        @items.where(item_type: @item_type)
    end

    return if @query.blank?

    pattern =
      "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"

    @items =
      @items.where(
        <<~SQL.squish,
          items.name ILIKE :pattern OR
          items.sku ILIKE :pattern OR
          items.barcode ILIKE :pattern
        SQL
        pattern: pattern
      )
  end

  def show
  end

  def new
    @item =
      current_organization.items.new(
        item_type: "product",
        selling_price: 0,
        purchase_cost: 0,
        track_inventory: true,
        active: true
      )

    load_form_options
  end

  def create
    @item =
      current_organization
        .items
        .new(item_params)

    if @item.save
      redirect_to @item,
                  notice: "#{@item.name} was created."
    else
      load_form_options

      render :new,
             status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @item.update(item_params)
      redirect_to @item,
                  notice: "#{@item.name} was updated."
    else
      load_form_options

      render :edit,
             status: :unprocessable_entity
    end
  end

  def toggle_status
    @item.update!(active: !@item.active?)

    status =
      @item.active? ? "enabled" : "disabled"

    redirect_to items_path,
                notice: "#{@item.name} was #{status}."
  end

  private

  def require_product_setup_management!
    return if current_membership&.product_setup_management?

    redirect_to dashboard_path,
                alert:
                  "Your role cannot manage products."
  end

  def set_item
    @item =
      current_organization
        .items
        .find(params[:id])
  end

  def load_form_options
    @product_categories =
      available_product_categories

    @unit_of_measures =
      available_unit_of_measures

    @tax_rates =
      available_tax_rates
  end

  def available_product_categories
    scope =
      current_organization.product_categories

    selected_id =
      @item&.product_category_id

    scope
      .where(active: true)
      .or(scope.where(id: selected_id))
      .alphabetical
  end

  def available_unit_of_measures
    scope =
      current_organization.unit_of_measures

    selected_id =
      @item&.unit_of_measure_id

    scope
      .where(active: true)
      .or(scope.where(id: selected_id))
      .alphabetical
  end

  def available_tax_rates
    scope =
      current_organization.tax_rates

    selected_id =
      @item&.tax_rate_id

    scope
      .where(active: true)
      .or(scope.where(id: selected_id))
      .alphabetical
  end

  def item_params
    params.require(:item).permit(
      :name,
      :description,
      :sku,
      :barcode,
      :item_type,
      :product_category_id,
      :unit_of_measure_id,
      :tax_rate_id,
      :selling_price,
      :purchase_cost,
      :track_inventory
    )
  end
end
