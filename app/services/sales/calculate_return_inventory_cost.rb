module Sales
  class CalculateReturnInventoryCost
    class CostError < StandardError; end

    def self.call(
      organization:,
      sale_return:
    )
      new(
        organization: organization,
        sale_return: sale_return
      ).call
    end

    def initialize(
      organization:,
      sale_return:
    )
      @organization = organization
      @sale_return = sale_return
    end

    def call
      validate_context!

      lines =
        restock_lines

      return 0.to_d if lines.empty?

      validate_stock_movements!(
        lines
      )

      money(
        lines.sum(
          0.to_d
        ) do |line|
          line.quantity.to_d *
            unit_cost_for(line)
        end
      )
    end

    private

    attr_reader :organization,
                :sale_return

    def validate_context!
      unless sale_return&.persisted?
        raise CostError,
              "A saved sale return is required"
      end

      return if sale_return.organization_id ==
                organization.id

      raise CostError,
            "The sale return belongs to another organization"
    end

    def restock_lines
      sale_return
        .sale_return_lines
        .includes(
          :item,
          :inventory_batch
        )
        .select do |line|
          line.stock_restock? &&
            line.item.stockable?
        end
    end

    def unit_cost_for(line)
      return line.unit_cost.to_d unless
        line.item.tracks_expiry?

      batch =
        line.inventory_batch

      unless batch
        raise CostError,
              "Expiry-tracked return has no inventory batch"
      end

      batch.unit_cost.to_d
    end

    def validate_stock_movements!(lines)
      expected =
        lines.each_with_object(
          Hash.new(0.to_d)
        ) do |line, quantities|
          key =
            [
              line.item_id,
              line.item.tracks_expiry? ?
                line.inventory_batch_id :
                nil
            ]

          quantities[key] +=
            line.quantity.to_d
        end

      actual =
        sale_return
          .stock_movements
          .where(
            movement_type: "sale_return"
          )
          .each_with_object(
            Hash.new(0.to_d)
          ) do |movement, quantities|
            key =
              [
                movement.item_id,
                movement.inventory_batch_id
              ]

            quantities[key] +=
              movement.quantity_change.to_d.abs
          end

      return if expected == actual

      raise CostError,
            "Sale return stock movements do not match " \
            "the restocked return quantities"
    end

    def money(value)
      value.to_d.round(2)
    end
  end
end
