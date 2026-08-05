module Sales
  class Cart
    Line =
      Struct.new(
        :item,
        :quantity,
        :unit_price,
        :discount_amount,
        keyword_init: true
      )

    def initialize(
      organization:,
      branch:,
      data: nil
    )
      @organization = organization
      @branch = branch
      @data =
        (data || {})
          .deep_stringify_keys
    end

    attr_reader :organization,
                :branch

    def lines
      @lines ||= load_lines
    end

    def empty?
      lines.empty?
    end

    def item_count
      lines.length
    end

    def customer
      return if customer_id.blank?

      organization
        .customers
        .find_by(id: customer_id)
    end

    def customer_id
      data["customer_id"]
    end

    def customer_id=(value)
      if value.blank?
        data["customer_id"] = nil
        return
      end

      customer =
        organization.customers.find(value)

      data["customer_id"] = customer.id
    end

    def add_item(item:, quantity: 1)
      ensure_sellable_item!(item)

      mutate! do
        key = item.id.to_s
        existing = raw_lines[key] || {}

        existing_quantity =
          decimal_value(
            existing["quantity"].presence || 0,
            field: "quantity"
          )

        added_quantity =
          decimal_value(
            quantity,
            field: "quantity"
          )

        raw_lines[key] = {
          "quantity" =>
            (existing_quantity + added_quantity).to_s("F"),
          "unit_price" =>
            (
              existing["unit_price"].presence ||
              item.selling_price
            ).to_d.to_s("F"),
          "discount_amount" =>
            (
              existing["discount_amount"].presence || 0
            ).to_d.to_s("F")
        }
      end
    end

    def update_item(
      item_id:,
      quantity:,
      discount_amount: 0
    )
      key = item_id.to_s

      unless raw_lines.key?(key)
        raise Sales::InvalidLineError,
              "The selected item is not in the cart"
      end

      mutate! do
        raw_lines[key]["quantity"] =
          decimal_value(
            quantity,
            field: "quantity"
          ).to_s("F")

        raw_lines[key]["discount_amount"] =
          decimal_value(
            discount_amount,
            field: "discount"
          ).to_s("F")
      end
    end

    def remove_item(item_id:)
      raw_lines.delete(item_id.to_s)
      reset_calculations!
    end

    def clear!
      data["customer_id"] = nil
      data["lines"] = {}
      reset_calculations!
    end

    def line_for(item_id)
      lines.find do |line|
        line.item.id == item_id.to_i
      end
    end

    def calculation
      @calculation ||=
        if empty?
          empty_calculation
        else
          calculate_totals
        end
    end

    def to_session
      {
        "customer_id" => customer_id,
        "lines" => raw_lines.deep_dup
      }
    end

    private

    attr_reader :data

    def raw_lines
      data["lines"] ||= {}
    end

    def load_lines
      return [] if raw_lines.empty?

      item_ids =
        raw_lines.keys.map(&:to_i)

      items_by_id =
        organization
          .items
          .includes(
            :unit_of_measure,
            :tax_rate
          )
          .where(id: item_ids)
          .index_by(&:id)

      raw_lines.map do |item_id, attributes|
        item = items_by_id[item_id.to_i]

        unless item
          raise Sales::InvalidLineError,
                "A cart item is no longer available"
        end

        ensure_sellable_item!(item)

        Line.new(
          item: item,
          quantity:
            decimal_value(
              attributes["quantity"],
              field: "quantity"
            ),
          unit_price:
            decimal_value(
              attributes["unit_price"],
              field: "unit price"
            ),
          discount_amount:
            decimal_value(
              attributes["discount_amount"],
              field: "discount"
            )
        )
      end
    end

    def calculate_totals
      result =
        Sales::CalculateTotals.call(
          lines:
            lines.map do |line|
              {
                item: line.item,
                quantity: line.quantity,
                unit_price: line.unit_price,
                discount_amount:
                  line.discount_amount
              }
            end,
          prices_include_tax: true
        )

      validate_stock_availability!

      result
    end

    def validate_stock_availability!
      stock_items =
        lines.select do |line|
          line.item.stockable?
        end

      return if stock_items.empty?

      quantities_by_item_id =
        organization
          .stock_levels
          .where(
            branch: branch,
            item_id:
              stock_items.map {
                |line| line.item.id
              }
          )
          .pluck(
            :item_id,
            :quantity_on_hand
          )
          .to_h

      stock_items.each do |line|
        available =
          quantities_by_item_id
            .fetch(line.item.id, 0)
            .to_d

        next if line.quantity <= available

        raise Sales::InvalidLineError,
              "#{line.item.name} only has " \
              "#{available.to_s('F')} available at " \
              "#{branch.name}"
      end
    end

    def ensure_sellable_item!(item)
      unless item.organization_id ==
             organization.id
        raise Sales::InvalidLineError,
              "The selected item belongs to another organization"
      end

      return if item.active?

      raise Sales::InvalidLineError,
            "#{item.name} is inactive"
    end

    def mutate!
      previous_data = data.deep_dup

      yield

      reset_calculations!
      calculation
    rescue StandardError
      @data = previous_data
      reset_calculations!
      raise
    end

    def reset_calculations!
      @lines = nil
      @calculation = nil
    end

    def decimal_value(value, field:)
      BigDecimal(value.to_s)
    rescue ArgumentError, TypeError
      raise Sales::InvalidLineError,
            "Cart has an invalid #{field}"
    end

    def empty_calculation
      Sales::CalculateTotals::Result.new(
        lines: [],
        subtotal: 0.to_d,
        discount_total: 0.to_d,
        tax_total: 0.to_d,
        total: 0.to_d
      )
    end
  end
end
