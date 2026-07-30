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
      source: nil
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
                :source

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

    def post_locked_movement(stock_level)
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
          source: source
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
  end
end
