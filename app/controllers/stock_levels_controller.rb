class StockLevelsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_organization!
  before_action :require_inventory_view!

  before_action :require_inventory_adjustment_management!,
                only: :update_reorder_level

  before_action :load_branches
  before_action :set_branch

  def index
    @query = params[:q].to_s.strip

    @status =
      params[:status].presence_in(
        %w[all in_stock low_stock out_of_stock]
      ) || "all"

    items =
      current_organization
        .items
        .stock_tracked
        .where(item_type: "product")
        .includes(
          :product_category,
          :unit_of_measure
        )
        .alphabetical

    if @query.present?
      pattern =
        "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"

      items =
        items.where(
          <<~SQL.squish,
            items.name ILIKE :pattern OR
            items.sku ILIKE :pattern OR
            items.barcode ILIKE :pattern
          SQL
          pattern: pattern
        )
    end

    items = items.to_a

    levels_by_item_id =
      current_organization
        .stock_levels
        .where(
          branch: @branch,
          item_id: items.map(&:id)
        )
        .index_by(&:item_id)

    @inventory_rows =
      items.map do |item|
        build_inventory_row(
          item,
          levels_by_item_id[item.id]
        )
      end

    filter_inventory_rows
  end

  def update_reorder_level
    item =
      current_organization
        .items
        .stock_tracked
        .where(item_type: "product")
        .find(params[:item_id])

    level =
      current_organization
        .stock_levels
        .create_or_find_by!(
          branch: @branch,
          item: item
        ) do |stock_level|
          stock_level.quantity_on_hand = 0
          stock_level.reorder_level = 0
        end

    if level.update(
      reorder_level: params[:reorder_level]
    )
      redirect_to stock_levels_path(
        branch_id: @branch.id
      ),
                  notice:
                    "Reorder level for #{item.name} was updated."
    else
      redirect_to stock_levels_path(
        branch_id: @branch.id
      ),
                  alert:
                    level.errors.full_messages.to_sentence
    end
  end

  private

  def load_branches
    @branches =
      current_organization
        .branches
        .order(:name)
  end

  def set_branch
    requested_id = params[:branch_id].presence

    @branch =
      if requested_id
        @branches.find(requested_id)
      else
        preferred_branch
      end
  end

  def preferred_branch
    @branches.find_by(
      id: current_membership&.branch_id
    ) ||
      @branches.find_by(main: true) ||
      @branches.first
  end

  def build_inventory_row(item, level)
    quantity =
      level&.quantity_on_hand.to_d

    reorder_level =
      level&.reorder_level.to_d

    {
      item: item,
      level: level,
      quantity: quantity,
      reorder_level: reorder_level,
      low_stock:
        reorder_level.positive? &&
          quantity <= reorder_level,
      out_of_stock: quantity.zero?
    }
  end

  def filter_inventory_rows
    @inventory_rows =
      case @status
      when "in_stock"
        @inventory_rows.reject do |row|
          row[:quantity].zero?
        end
      when "low_stock"
        @inventory_rows.select do |row|
          row[:low_stock]
        end
      when "out_of_stock"
        @inventory_rows.select do |row|
          row[:out_of_stock]
        end
      else
        @inventory_rows
      end
  end
end
