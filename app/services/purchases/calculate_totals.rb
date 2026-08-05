module Purchases
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

    def self.call(lines:)
      new(lines: lines).call
    end

    def initialize(lines:)
      @lines = lines
    end

    def call
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
          money(
            calculated_lines.sum {
              |line| line[:gross_amount]
            }
          ),
        discount_total:
          money(
            calculated_lines.sum {
              |line| line[:discount_amount]
            }
          ),
        tax_total:
          money(
            calculated_lines.sum {
              |line| line[:tax_amount]
            }
          ),
        total:
          money(
            calculated_lines.sum {
              |line| line[:line_total]
            }
          )
      )
    end

    private

    attr_reader :lines

    def calculate_line(line, line_number:)
      item = line.item
      quantity = decimal(line.quantity)
      unit_cost = money(line.unit_cost)
      discount = money(line.discount_amount)

      unless quantity.positive?
        raise Purchases::InvalidLineError,
              "#{item.name} quantity must be greater than zero"
      end

      if unit_cost.negative?
        raise Purchases::InvalidLineError,
              "#{item.name} cost cannot be negative"
      end

      gross = money(quantity * unit_cost)

      if discount.negative?
        raise Purchases::InvalidLineError,
              "#{item.name} discount cannot be negative"
      end

      if discount > gross
        raise Purchases::InvalidLineError,
              "#{item.name} discount cannot exceed its value"
      end

      line_total =
        money(gross - discount)

      tax_rate = item.tax_rate

      tax_percentage =
        tax_rate&.percentage.to_d

      tax_amount =
        inclusive_tax(
          line_total,
          tax_percentage
        )

      {
        item: item,
        tax_rate: tax_rate,
        line_number: line_number,
        item_name: item.name,
        sku: item.sku,
        barcode: item.barcode,
        item_type: item.item_type,
        unit_name:
          item.unit_of_measure.name,
        unit_symbol:
          item.unit_of_measure.symbol,
        quantity: quantity,
        unit_cost: unit_cost,
        gross_amount: gross,
        discount_amount: discount,
        tax_percentage:
          tax_percentage,
        tax_amount: tax_amount,
        line_total: line_total
      }
    end

    def inclusive_tax(total, percentage)
      return 0.to_d unless percentage.positive?

      money(
        total * percentage /
          (100.to_d + percentage)
      )
    end

    def decimal(value)
      BigDecimal(value.to_s)
    rescue ArgumentError, TypeError
      raise Purchases::InvalidLineError,
            "Invalid purchase quantity"
    end

    def money(value)
      value.to_d.round(2)
    end
  end
end
