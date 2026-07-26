class ProductCategoriesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_organization!
  before_action :require_product_setup_management!

  before_action :set_product_category,
                only: %i[edit update toggle_status]

  def index
    @status =
      params[:status].presence_in(
        %w[active inactive all]
      ) || "active"

    @product_categories =
      current_organization
        .product_categories
        .alphabetical

    @product_categories =
      case @status
      when "inactive"
        @product_categories.where(active: false)
      when "all"
        @product_categories
      else
        @product_categories.active
      end
  end

  def new
    @product_category =
      current_organization.product_categories.new(
        active: true
      )
  end

  def create
    @product_category =
      current_organization
        .product_categories
        .new(product_category_params)

    if @product_category.save
      redirect_to product_categories_path,
                  notice:
                    "#{@product_category.name} was created."
    else
      render :new,
             status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @product_category.update(product_category_params)
      redirect_to product_categories_path,
                  notice:
                    "#{@product_category.name} was updated."
    else
      render :edit,
             status: :unprocessable_entity
    end
  end

  def toggle_status
    @product_category.update!(
      active: !@product_category.active?
    )

    status =
      @product_category.active? ? "enabled" : "disabled"

    redirect_to product_categories_path,
                notice:
                  "#{@product_category.name} was #{status}."
  end

  private

  def require_product_setup_management!
    return if current_membership&.product_setup_management?

    redirect_to dashboard_path,
                alert:
                  "Your role cannot manage product setup."
  end

  def set_product_category
    @product_category =
      current_organization
        .product_categories
        .find(params[:id])
  end

  def product_category_params
    params.require(:product_category).permit(
      :name,
      :description
    )
  end
end
