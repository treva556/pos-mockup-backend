module Inventory
  class PostMovement
    def self.call(...)
      new(...).call
    end

    def initialize(
      organization:,
      branch:,
      item:,
      recorded_by:,
      movement_type:,
      quantity_change:,
      occurred_at: Time.current,
      reference: nil,
      notes: nil,
      source: nil,
      inventory_batch: nil
    )
      @organization = organization
      @branch = branch
      @item = item
      @recorded_by = recorded_by
      @movement_type = movement_type
      @quantity_change = quantity_change.to_d
      @occurred_at = occurred_at
      @reference = reference
      @notes = notes
      @source = source
      @inventory_batch = inventory_batch
    end

    def call
      StockLevel.transaction do
        stock_level = find_or_create_stock_level

        stock_level.with_lock do
          post_locked_movement(stock_level)
        end
      end
    end

    private

    attr_reader :organization,
                :branch,
                :item,
                :recorded_by,
                :movement_type,
                :quantity_change,
                :occurred_at,
                :reference,
                :notes,
                :source,
                :inventory_batch

    def find_or_create_stock_level
      StockLevel.create_or_find_by!(
        organization: organization,
        branch: branch,
        item: item
      ) do |level|
        level.quantity_on_hand = 0
        level.reorder_level = 0
      end
    end

    def ensure_opening_is_first!(stock_level)
        return unless movement_type.to_s == "opening"

        no_previous_activity =
            stock_level.last_movement_at.blank? &&
            stock_level.quantity_on_hand.to_d.zero?

        return if no_previous_activity

        raise Inventory::InvalidOpeningStockError,
                "Opening stock can only be recorded before other stock movements"
    end

    def post_locked_movement(stock_level)
        ensure_opening_is_first!(stock_level)
        validate_inventory_batch!

        new_quantity =
            stock_level.quantity_on_hand.to_d +
            quantity_change

        raise_insufficient_stock! if new_quantity.negative?


      movement =
        organization.stock_movements.create!(
          branch: branch,
          item: item,
          recorded_by: recorded_by,
          movement_type: movement_type,
          quantity_change: quantity_change,
          occurred_at: occurred_at,
          reference: reference,
          notes: notes,
          source: source,
          inventory_batch: inventory_batch,
        )

      stock_level.update!(
        quantity_on_hand: new_quantity,
        last_movement_at:
          latest_movement_time(stock_level)
      )

      movement
    end

    def latest_movement_time(stock_level)
      [
        stock_level.last_movement_at,
        occurred_at
      ].compact.max
    end

    def raise_insufficient_stock!
      raise Inventory::InsufficientStockError,
            "#{item.name} does not have enough stock " \
            "at #{branch.name}"
    end
    def validate_inventory_batch!
      return if inventory_batch.blank?

      valid =
        inventory_batch.organization_id ==
          organization.id &&
        inventory_batch.branch_id ==
          branch.id &&
        inventory_batch.item_id ==
          item.id

      return if valid

      raise ArgumentError,
            "Inventory batch does not match the movement context"
    end
  end
end
