class CreateSaleLines < ActiveRecord::Migration[8.1]
  def change
    create_table :sale_lines do |t|
      t.references :organization,
                   null: false,
                   foreign_key: true

      t.references :sale,
                   null: false,
                   foreign_key: true

      t.references :item,
                   null: false,
                   foreign_key: true

      t.references :tax_rate,
                   null: true,
                   foreign_key: true

      t.integer :line_number,
                null: false

      t.string :item_name,
               null: false

      t.string :sku
      t.string :barcode

      t.string :item_type,
               null: false

      t.string :unit_name,
               null: false

      t.string :unit_symbol,
               null: false

      t.decimal :quantity,
                precision: 15,
                scale: 4,
                null: false

      t.decimal :unit_price,
                precision: 15,
                scale: 2,
                null: false

      t.decimal :unit_cost,
                precision: 15,
                scale: 2,
                null: false,
                default: 0

      t.decimal :gross_amount,
                precision: 15,
                scale: 2,
                null: false

      t.decimal :discount_amount,
                precision: 15,
                scale: 2,
                null: false,
                default: 0

      t.decimal :tax_rate_percentage,
                precision: 7,
                scale: 4,
                null: false,
                default: 0

      t.decimal :tax_amount,
                precision: 15,
                scale: 2,
                null: false,
                default: 0

      t.decimal :line_total,
                precision: 15,
                scale: 2,
                null: false

      t.timestamps
    end

    add_index :sale_lines,
              %i[sale_id line_number],
              unique: true,
              name: "index_sale_lines_on_sale_and_line_number"

    add_index :sale_lines,
              %i[organization_id sale_id]

    add_index :sale_lines,
              %i[organization_id item_id]

    add_check_constraint :sale_lines,
                         "line_number > 0",
                         name: "sale_lines_positive_line_number"

    add_check_constraint :sale_lines,
                         "quantity > 0",
                         name: "sale_lines_positive_quantity"

    add_check_constraint :sale_lines,
                         "unit_price >= 0",
                         name: "sale_lines_nonnegative_unit_price"

    add_check_constraint :sale_lines,
                         "unit_cost >= 0",
                         name: "sale_lines_nonnegative_unit_cost"

    add_check_constraint :sale_lines,
                         "gross_amount >= 0",
                         name: "sale_lines_nonnegative_gross"

    add_check_constraint :sale_lines,
                         "discount_amount >= 0",
                         name: "sale_lines_nonnegative_discount"

    add_check_constraint :sale_lines,
                         "tax_rate_percentage >= 0",
                         name: "sale_lines_nonnegative_tax_rate"

    add_check_constraint :sale_lines,
                         "tax_rate_percentage <= 100",
                         name: "sale_lines_tax_rate_within_percentage"

    add_check_constraint :sale_lines,
                         "tax_amount >= 0",
                         name: "sale_lines_nonnegative_tax"

    add_check_constraint :sale_lines,
                         "line_total >= 0",
                         name: "sale_lines_nonnegative_total"

    add_check_constraint :sale_lines,
                         "discount_amount <= gross_amount",
                         name: "sale_lines_discount_within_gross"

    add_check_constraint :sale_lines,
                         "tax_amount <= line_total",
                         name: "sale_lines_tax_within_total"

    add_check_constraint :sale_lines,
                         "line_total <= gross_amount",
                         name: "sale_lines_total_within_gross"

    add_check_constraint :sale_lines,
                         "item_type IN ('product', 'service')",
                         name: "sale_lines_allowed_item_type"
  end
end
