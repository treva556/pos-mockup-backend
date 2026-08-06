module Inventory
  class SellableQuantity
    def self.call(
      organization:,
      branch:,
      item:,
      on: Date.current
    )
      new(
        organization: organization,
        branch: branch,
        item: item,
        on: on
      ).call
    end

    def initialize(
      organization:,
      branch:,
      item:,
      on:
    )
      @organization = organization
      @branch = branch
      @item = item
      @on = on
    end

    def call
      return normal_stock_quantity unless item.tracks_expiry?

      organization
        .inventory_batches
        .where(
          branch: branch,
          item: item
        )
        .sellable(on)
        .sum(:quantity_remaining)
        .to_d
    end

    private

    attr_reader :organization,
                :branch,
                :item,
                :on

    def normal_stock_quantity
      organization
        .stock_levels
        .find_by(
          branch: branch,
          item: item
        )
        &.quantity_on_hand
        .to_d
    end
  end
end
