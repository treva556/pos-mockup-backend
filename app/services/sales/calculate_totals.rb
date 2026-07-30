module Sales
  class CalculateTotals
    Result =
      Struct.new(
        :lines,
        :subtotal,
        :discount_total,
        :tax_total,
        :total,
        keyword_init: true
      )

    def self.call(lines:, prices_include_tax: true)
      new(
        lines: lines,
        prices_include_tax: prices_include_tax
      ).call
    end

    def initialize(lines:, prices_include_tax:)
      @lines = Array(lines)
      @prices_include_tax = prices_include_tax
    end

    def call
      validate_price_mode!
      validate_lines_present!

      calculated_lines =
        lines.each_with_index.map do |line, index|
          calculate_line(
            line,
            line_number: index + 1
          )
        end

      Result.new(
        lines: calculated_lines,
        subtotal:
          calculated_lines.sum(0.to_d) do |line|
            line[:gross_amount]
          end,
        discount_total:
          calculated_lines.sum(0.to_d) do |line|
            line[:discount_amount]
          end,
        tax_total:
          calculated_lines.sum(0.to_d) do |line|
            line[:tax_amount]
          end,
        total:
          calculated_lines.sum(0.to_d) do |line|
            line[:line_total]
          end
      )
    end

    private

    attr_reader :lines,
                :prices_include_tax

    def validate_price_mode!
      return if prices_include_tax

      raise ArgumentError,
            "Tax-exclusive pricing is not supported yet"
    end

    def validate_lines_present!
      return if lines.any?

      raise Sales::InvalidLineError,
            "A sale must contain at least one item"
    end

    def calculate_line(raw_line, line_number:)
      attributes =
        raw_line
          .to_h
          .with_indifferent_access

      item = attributes[:item]

      unless item.present?
        raise Sales::InvalidLineError,
              "Line #{line_number} must have an item"
      end

      validate_item!(
        item,
        line_number: line_number
      )

      quantity =
        decimal_value(
          attributes[:quantity],
          field: "quantity",
          line_number: line_number
        )

      unit_price =
        decimal_value(
          attributes[:unit_price].presence ||
            item.selling_price,
          field: "unit price",
          line_number: line_number
        )

      discount_amount =
        decimal_value(
          attributes[:discount_amount].presence || 0,
          field: "discount",
          line_number: line_number
        )

      validate_quantity!(
        item,
        quantity,
        line_number: line_number
      )

      validate_nonnegative!(
        unit_price,
        field: "unit price",
        line_number: line_number
      )

      validate_nonnegative!(
        discount_amount,
        field: "discount",
        line_number: line_number
      )

      gross_amount =
        money(quantity * unit_price)

      discount_amount =
        money(discount_amount)

      if discount_amount > gross_amount
        raise Sales::InvalidLineError,
              "Line #{line_number} discount cannot " \
              "exceed its gross amount"
      end

      line_total =
        money(
          gross_amount - discount_amount
        )

      tax_rate = item_tax_rate(item)

      tax_percentage =
        tax_percentage_for(tax_rate)

      tax_amount =
        inclusive_tax_amount(
          line_total,
          tax_percentage
        )

      unit = item.unit_of_measure

      {
        item: item,
        tax_rate: tax_rate,
        line_number: line_number,
        item_name: item.name,
        sku: item.sku,
        barcode: item.barcode,
        item_type: item.item_type,
        unit_name: unit.name,
        unit_symbol: unit.symbol,
        quantity: quantity,
        unit_price: money(unit_price),
        unit_cost: money(item.purchase_cost || 0),
        gross_amount: gross_amount,
        discount_amount: discount_amount,
        tax_rate_percentage: tax_percentage,
        tax_amount: tax_amount,
        line_total: line_total
      }
    end

    def validate_item!(item, line_number:)
      unless item.persisted?
        raise Sales::InvalidLineError,
              "Line #{line_number} item must be saved"
      end

      return if item.active?

      raise Sales::InvalidLineError,
            "Line #{line_number} item is inactive"
    end

    def validate_quantity!(
      item,
      quantity,
      line_number:
    )
      unless quantity.positive?
        raise Sales::InvalidLineError,
              "Line #{line_number} quantity must be positive"
      end

      unit = item.unit_of_measure

      return if unit.decimal_allowed?
      return if (quantity % 1).zero?

      raise Sales::InvalidLineError,
            "Line #{line_number} quantity must be " \
            "a whole number for #{unit.name}"
    end

    def validate_nonnegative!(
      value,
      field:,
      line_number:
    )
      return unless value.negative?

      raise Sales::InvalidLineError,
            "Line #{line_number} #{field} cannot be negative"
    end

    def decimal_value(value, field:, line_number:)
      BigDecimal(value.to_s)
    rescue ArgumentError, TypeError
      raise Sales::InvalidLineError,
            "Line #{line_number} has an invalid #{field}"
    end

    def item_tax_rate(item)
      return unless item.respond_to?(:tax_rate)

      item.tax_rate
    end

    def tax_percentage_for(tax_rate)
      return 0.to_d if tax_rate.blank?

      attribute =
        %i[
          percentage
          rate
          rate_percentage
        ].find do |candidate|
          tax_rate.respond_to?(candidate)
        end

      unless attribute
        raise Sales::InvalidLineError,
              "The selected tax rate has no percentage"
      end

      percentage =
        tax_rate.public_send(attribute).to_d

      unless percentage.between?(0, 100)
        raise Sales::InvalidLineError,
              "Tax percentage must be between 0 and 100"
      end

      percentage
    end

    def inclusive_tax_amount(
      line_total,
      percentage
    )
      return 0.to_d if percentage.zero?

      money(
        line_total *
          percentage /
          (100.to_d + percentage)
      )
    end

    def money(value)
      value.to_d.round(2)
    end
  end
end
