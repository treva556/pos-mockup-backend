class StockMovementsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_organization!
  before_action :require_inventory_view!

  before_action :set_stock_movement,
                only: :show

  def index
    load_filter_options
    load_filters

    @stock_movements =
      current_organization
        .stock_movements
        .includes(
          :branch,
          :item,
          :recorded_by,
          :source
        )
        .recent_first

    filter_by_branch
    filter_by_item
    filter_by_movement_type
    filter_by_query
  end

  def show
  end

  private

  def set_stock_movement
    @stock_movement =
      current_organization
        .stock_movements
        .includes(
          :branch,
          :item,
          :recorded_by,
          :source
        )
        .find(params[:id])
  end

  def load_filter_options
    @branches =
      current_organization
        .branches
        .order(:name)

    @items =
      current_organization
        .items
        .stock_tracked
        .where(item_type: "product")
        .alphabetical
  end

  def load_filters
    @query = params[:q].to_s.strip
    @branch_id = params[:branch_id].presence
    @item_id = params[:item_id].presence

    @movement_type =
      params[:movement_type].presence_in(
        StockMovement.movement_types.keys + [ "all" ]
      ) || "all"
  end

  def filter_by_branch
    return if @branch_id.blank?

    branch = @branches.find(@branch_id)

    @stock_movements =
      @stock_movements.where(branch: branch)
  end

  def filter_by_item
    return if @item_id.blank?

    item = @items.find(@item_id)

    @stock_movements =
      @stock_movements.where(item: item)
  end

  def filter_by_movement_type
    return if @movement_type == "all"

    @stock_movements =
      @stock_movements.where(
        movement_type: @movement_type
      )
  end

  def filter_by_query
    return if @query.blank?

    pattern =
      "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"

    @stock_movements =
      @stock_movements.where(
        <<~SQL.squish,
          stock_movements.reference ILIKE :pattern OR
          stock_movements.notes ILIKE :pattern
        SQL
        pattern: pattern
      )
  end
end
