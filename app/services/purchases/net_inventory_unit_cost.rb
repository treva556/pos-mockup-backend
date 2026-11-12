module Purchases
  class NetInventoryUnitCost
    class CostError < StandardError; end

    def self.call(purchase_line:)
      new(
        purchase_line: purchase_line
      ).call
    end

    def initialize(purchase_line:)
      @purchase_line =
        purchase_line
    end

    def call
      quantity =
        purchase_line.quantity.to_d

      unless quantity.positive?
        raise CostError,
              "Purchase quantity must be greater than zero"
      end

      net_line_cost =
        purchase_line.line_total.to_d -
        purchase_line.tax_amount.to_d

      if net_line_cost.negative?
        raise CostError,
              "Purchase inventory cost cannot be negative"
      end

      (
        net_line_cost /
          quantity
      ).round(2)
    end

    private

    attr_reader :purchase_line
  end
end
