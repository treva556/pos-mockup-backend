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
        %w[
          all
          in_stock
          low_stock
          out_of_stock
          expired
          unassigned
        ]
      ) || "all"

    items = filtered_items.to_a

    levels_by_item_id =
      current_organization
        .stock_levels
        .where(
          branch: @branch,
          item_id: items.map(&:id)
        )
        .index_by(&:item_id)

    batch_quantities =
      batch_quantities_by_item_id(items)

    @inventory_rows =
      items.map do |item|
        build_inventory_row(
          item: item,
          level: levels_by_item_id[item.id],
          batch_quantities: batch_quantities
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

  def filtered_items
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

    return items if @query.blank?

    pattern =
      "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"

    items.where(
      <<~SQL.squish,
        items.name ILIKE :pattern OR
        items.sku ILIKE :pattern OR
        items.barcode ILIKE :pattern
      SQL
      pattern: pattern
    )
  end

  def batch_quantities_by_item_id(items)
    expiry_item_ids =
      items
        .select(&:tracks_expiry?)
        .map(&:id)

    empty_result = {
      assigned: {},
      sellable: {},
      expired: {}
    }

    return empty_result if expiry_item_ids.empty?

    batches =
      current_organization
        .inventory_batches
        .where(
          branch: @branch,
          item_id: expiry_item_ids
        )

    {
      assigned:
        batches
          .group(:item_id)
          .sum(:quantity_remaining),

      sellable:
        batches
          .sellable(Date.current)
          .group(:item_id)
          .sum(:quantity_remaining),

      expired:
        batches
          .with_quantity
          .expired(Date.current)
          .group(:item_id)
          .sum(:quantity_remaining)
    }
  end

  def build_inventory_row(
    item:,
    level:,
    batch_quantities:
  )
    physical_quantity =
      level&.quantity_on_hand.to_d

    reorder_level =
      level&.reorder_level.to_d

    quantities =
      quantities_for(
        item: item,
        physical_quantity: physical_quantity,
        batch_quantities: batch_quantities
      )

    sellable_quantity =
      quantities[:sellable]

    {
      item: item,
      level: level,

      # Kept for compatibility with older view code.
      quantity: physical_quantity,

      physical_quantity: physical_quantity,
      sellable_quantity: sellable_quantity,
      expired_quantity: quantities[:expired],
      unassigned_quantity: quantities[:unassigned],
      reorder_level: reorder_level,

      low_stock:
        reorder_level.positive? &&
          sellable_quantity.positive? &&
          sellable_quantity <= reorder_level,

      out_of_stock:
        sellable_quantity.zero?
    }
  end

  def quantities_for(
    item:,
    physical_quantity:,
    batch_quantities:
  )
    unless item.tracks_expiry?
      return {
        sellable: physical_quantity,
        expired: 0.to_d,
        unassigned: 0.to_d
      }
    end

    assigned_quantity =
      batch_quantities[:assigned]
        .fetch(item.id, 0)
        .to_d

    sellable_quantity =
      batch_quantities[:sellable]
        .fetch(item.id, 0)
        .to_d

    expired_quantity =
      batch_quantities[:expired]
        .fetch(item.id, 0)
        .to_d

    unassigned_quantity =
      [
        physical_quantity - assigned_quantity,
        0.to_d
      ].max

    {
      sellable: sellable_quantity,
      expired: expired_quantity,
      unassigned: unassigned_quantity
    }
  end

  def filter_inventory_rows
    @inventory_rows =
      case @status
      when "in_stock"
        @inventory_rows.select do |row|
          row[:sellable_quantity].positive?
        end

      when "low_stock"
        @inventory_rows.select do |row|
          row[:low_stock]
        end

      when "out_of_stock"
        @inventory_rows.select do |row|
          row[:out_of_stock]
        end

      when "expired"
        @inventory_rows.select do |row|
          row[:expired_quantity].positive?
        end

      when "unassigned"
        @inventory_rows.select do |row|
          row[:unassigned_quantity].positive?
        end

      else
        @inventory_rows
      end
  end

  def load_branches
    branches =
      current_organization
        .branches
        .where(active: true)
        .order(:name)

    if current_membership&.branch_id.present?
      branches =
        branches.where(
          id: current_membership.branch_id
        )
    end

    @branches = branches
  end

  def set_branch
    requested_id =
      params[:branch_id].presence

    @branch =
      if requested_id.present?
        @branches.find(requested_id)
      else
        preferred_branch
      end

    return if @branch.present?

    raise ActiveRecord::RecordNotFound,
          "No active inventory branch is available"
  end

  def preferred_branch
    @branches.find_by(
      id: current_membership&.branch_id
    ) ||
      @branches.find_by(main: true) ||
      @branches.first
  end
end
