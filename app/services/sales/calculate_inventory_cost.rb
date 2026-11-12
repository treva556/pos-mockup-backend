module Sales
  class CalculateInventoryCost
    class CostError < StandardError; end

    def self.call(
      organization:,
      sale:
    )
      new(
        organization: organization,
        sale: sale
      ).call
    end

    def initialize(
      organization:,
      sale:
    )
      @organization =
        organization

      @sale =
        sale
    end

    def call
      validate_context!

      lines =
        stockable_lines

      return 0.to_d if lines.empty?

      movements =
        sale_movements

      validate_movement_quantities!(
        lines: lines,
        movements: movements
      )

      money(
        normal_inventory_cost(
          lines
        ) +
        expiry_inventory_cost(
          lines: lines,
          movements: movements
        )
      )
    end

    private

    attr_reader :organization,
                :sale

    def validate_context!
      unless sale&.persisted?
        raise CostError,
              "A saved sale is required"
      end

      return if sale.organization_id ==
                organization.id

      raise CostError,
            "The sale belongs to another organization"
    end

    def stockable_lines
      sale
        .sale_lines
        .includes(
          :item
        )
        .select do |line|
          line.item.stockable?
        end
    end

    def sale_movements
      sale
        .stock_movements
        .where(
          movement_type: "sale"
        )
        .includes(
          :inventory_batch
        )
        .to_a
    end

    def validate_movement_quantities!(
      lines:,
      movements:
    )
      expected =
        quantities_from_lines(
          lines
        )

      actual =
        quantities_from_movements(
          movements
        )

      expected.each do |item_id, quantity|
        actual_quantity =
          actual.fetch(
            item_id,
            0.to_d
          )

        next if actual_quantity ==
                quantity

        item =
          lines
            .find do |line|
              line.item_id == item_id
            end
            .item

        raise CostError,
              "Inventory movements do not match " \
              "the sold quantity for #{item.name}"
      end
    end

    def quantities_from_lines(lines)
      lines.each_with_object(
        Hash.new(0.to_d)
      ) do |line, quantities|
        quantities[line.item_id] +=
          line.quantity.to_d
      end
    end

    def quantities_from_movements(
      movements
    )
      movements.each_with_object(
        Hash.new(0.to_d)
      ) do |movement, quantities|
        quantities[movement.item_id] +=
          movement
            .quantity_change
            .to_d
            .abs
      end
    end

    def normal_inventory_cost(lines)
      lines
        .reject do |line|
          line.item.tracks_expiry?
        end
        .sum(
          0.to_d
        ) do |line|
          line.quantity.to_d *
            line.unit_cost.to_d
        end
    end

    def expiry_inventory_cost(
      lines:,
      movements:
    )
      tracked_item_ids =
        lines
          .select do |line|
            line.item.tracks_expiry?
          end
          .map(
            &:item_id
          )
          .uniq

      return 0.to_d if tracked_item_ids.empty?

      tracked_movements =
        movements.select do |movement|
          tracked_item_ids.include?(
            movement.item_id
          )
        end

      tracked_movements.sum(
        0.to_d
      ) do |movement|
        batch =
          movement.inventory_batch

        unless batch
          raise CostError,
                "Expiry-tracked sale movement " \
                "has no inventory batch"
        end

        movement
          .quantity_change
          .to_d
          .abs *
          batch.unit_cost.to_d
      end
    end

    def money(value)
      value.to_d.round(2)
    end
  end
end
