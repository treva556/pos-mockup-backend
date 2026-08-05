module Purchases
  class Cart
    Line =
      Struct.new(
        :item,
        :quantity,
        :unit_cost,
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

    def supplier_id
      data["supplier_id"].presence
    end

    def supplier_id=(value)
      data["supplier_id"] =
        value.presence
    end

    def supplier
      return if supplier_id.blank?

      organization
        .suppliers
        .find(supplier_id)
    rescue ActiveRecord::RecordNotFound
      raise Purchases::ReceivingError,
            "The selected supplier is unavailable"
    end

    def supplier_invoice_number
      data["supplier_invoice_number"]
        .to_s
        .strip
        .presence
    end

    def supplier_invoice_number=(value)
      data["supplier_invoice_number"] =
        value.to_s.strip
    end

    def purchased_on
      value =
        data["purchased_on"].presence ||
        Date.current.to_s

      ActiveModel::Type::Date
        .new
        .cast(value)
    end

    def purchased_on=(value)
      data["purchased_on"] =
        value.to_s
    end

    def notes
      data["notes"]
        .to_s
        .strip
        .presence
    end

    def notes=(value)
      data["notes"] =
        value.to_s
    end

    def add_item(
      item:,
      quantity: 1,
      unit_cost: nil
    )
      validate_item!(item)

      cost =
        if unit_cost.present?
          decimal(
            unit_cost,
            label: "unit cost"
          )
        else
          item.purchase_cost.to_d
        end

      raw_lines[item.id.to_s] = {
        "quantity" =>
          decimal(
            quantity,
            label: "quantity"
          ).to_s("F"),
        "unit_cost" =>
          cost.to_s("F"),
        "discount_amount" =>
          "0.0"
      }

      reset_lines!
    end

    def update_item(
      item_id:,
      quantity:,
      unit_cost:,
      discount_amount: 0
    )
      key = item_id.to_s

      unless raw_lines.key?(key)
        raise Purchases::InvalidLineError,
              "The selected purchase item is unavailable"
      end

      raw_lines[key] = {
        "quantity" =>
          decimal(
            quantity,
            label: "quantity"
          ).to_s("F"),
        "unit_cost" =>
          decimal(
            unit_cost,
            label: "unit cost"
          ).to_s("F"),
        "discount_amount" =>
          decimal(
            discount_amount,
            label: "discount"
          ).to_s("F")
      }

      reset_lines!
      calculation
      self
    end

    def remove_item(item_id:)
      raw_lines.delete(item_id.to_s)
      reset_lines!
    end

    def clear!
      data.clear
      reset_lines!
    end

    def calculation
      Purchases::CalculateTotals.call(
        lines: lines
      )
    end

    def to_session
      data.deep_dup
    end

    private

    attr_reader :data

    def raw_lines
      data["lines"] ||= {}
    end

    def load_lines
      raw_lines.map do |item_id, attributes|
        item =
          organization.items.find(item_id)

        validate_item!(item)

        Line.new(
          item: item,
          quantity:
            decimal(
              attributes["quantity"],
              label: "quantity"
            ),
          unit_cost:
            decimal(
              attributes["unit_cost"],
              label: "unit cost"
            ),
          discount_amount:
            decimal(
              attributes["discount_amount"],
              label: "discount"
            )
        )
      end
    rescue ActiveRecord::RecordNotFound
      raise Purchases::InvalidLineError,
            "A purchase item is no longer available"
    end

    def validate_item!(item)
      unless item.organization_id ==
             organization.id
        raise Purchases::InvalidLineError,
              "The item belongs to another organization"
      end

      if item.respond_to?(:active?) &&
         !item.active?
        raise Purchases::InvalidLineError,
              "#{item.name} is inactive"
      end

      return if item.stockable?

      raise Purchases::InvalidLineError,
            "#{item.name} is not an inventory item"
    end

    def decimal(value, label:)
      BigDecimal(value.to_s)
    rescue ArgumentError, TypeError
      raise Purchases::InvalidLineError,
            "Invalid #{label}"
    end

    def reset_lines!
      @lines = nil
    end
  end
end
