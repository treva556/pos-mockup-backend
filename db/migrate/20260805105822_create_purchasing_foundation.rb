class CreatePurchasingFoundation <
  ActiveRecord::Migration[8.1]
  def change
    add_column :branches,
               :next_purchase_sequence,
               :bigint,
               null: false,
               default: 1

    add_check_constraint(
      :branches,
      "next_purchase_sequence > 0",
      name: "branches_next_purchase_sequence_positive"
    )

    create_table :purchases do |t|
      t.references :organization,
                   null: false,
                   foreign_key: true

      t.references :branch,
                   null: false,
                   foreign_key: true

      t.references :supplier,
                   null: false,
                   foreign_key: true

      t.references :recorded_by,
                   null: false,
                   foreign_key: {
                     to_table: :users
                   }

      t.string :purchase_number,
               null: false

      t.string :supplier_invoice_number

      t.string :status,
               null: false,
               default: "received"

      t.string :payment_status,
               null: false,
               default: "unpaid"

      t.date :purchased_on,
             null: false

      t.datetime :received_at,
                 null: false

      t.date :due_on

      t.boolean :prices_include_tax,
                null: false,
                default: true

      t.decimal :subtotal,
                precision: 15,
                scale: 2,
                null: false,
                default: 0

      t.decimal :discount_total,
                precision: 15,
                scale: 2,
                null: false,
                default: 0

      t.decimal :tax_total,
                precision: 15,
                scale: 2,
                null: false,
                default: 0

      t.decimal :total,
                precision: 15,
                scale: 2,
                null: false,
                default: 0

      t.decimal :amount_paid,
                precision: 15,
                scale: 2,
                null: false,
                default: 0

      t.decimal :balance_due,
                precision: 15,
                scale: 2,
                null: false,
                default: 0

      t.text :notes

      t.timestamps
    end

    add_index :purchases,
              %i[organization_id purchase_number],
              unique: true

    add_index :purchases,
              %i[organization_id purchased_on]

    add_index :purchases,
              %i[organization_id payment_status]

    add_index :purchases,
              %i[
                organization_id
                supplier_id
                supplier_invoice_number
              ],
              unique: true,
              where:
                "supplier_invoice_number IS NOT NULL " \
                "AND supplier_invoice_number <> ''",
              name:
                "index_unique_supplier_purchase_invoice"

    add_check_constraint(
      :purchases,
      "status IN ('draft', 'received', 'cancelled')",
      name: "purchases_status_valid"
    )

    add_check_constraint(
      :purchases,
      "payment_status IN " \
      "('unpaid', 'partially_paid', 'paid')",
      name: "purchases_payment_status_valid"
    )

    add_check_constraint(
      :purchases,
      <<~SQL.squish,
        subtotal >= 0 AND
        discount_total >= 0 AND
        tax_total >= 0 AND
        total >= 0 AND
        amount_paid >= 0 AND
        balance_due >= 0
      SQL
      name: "purchases_amounts_nonnegative"
    )

    add_check_constraint(
      :purchases,
      "amount_paid <= total",
      name: "purchases_amount_paid_not_above_total"
    )

    add_check_constraint(
      :purchases,
      "due_on IS NULL OR due_on >= purchased_on",
      name: "purchases_due_date_valid"
    )

    create_table :purchase_lines do |t|
      t.references :organization,
                   null: false,
                   foreign_key: true

      t.references :purchase,
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

      t.decimal :unit_cost,
                precision: 15,
                scale: 2,
                null: false

      t.decimal :gross_amount,
                precision: 15,
                scale: 2,
                null: false

      t.decimal :discount_amount,
                precision: 15,
                scale: 2,
                null: false,
                default: 0

      t.decimal :tax_percentage,
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

    add_index :purchase_lines,
              %i[purchase_id line_number],
              unique: true

    add_check_constraint(
      :purchase_lines,
      "line_number > 0",
      name: "purchase_lines_line_number_positive"
    )

    add_check_constraint(
      :purchase_lines,
      "quantity > 0",
      name: "purchase_lines_quantity_positive"
    )

    add_check_constraint(
      :purchase_lines,
      <<~SQL.squish,
        unit_cost >= 0 AND
        gross_amount >= 0 AND
        discount_amount >= 0 AND
        tax_percentage >= 0 AND
        tax_amount >= 0 AND
        line_total >= 0
      SQL
      name: "purchase_lines_amounts_nonnegative"
    )

    create_table :purchase_payments do |t|
      t.references :organization,
                   null: false,
                   foreign_key: true

      t.references :purchase,
                   null: false,
                   foreign_key: true

      t.references :payment_method,
                   null: false,
                   foreign_key: true

      t.references :money_account,
                   null: false,
                   foreign_key: true

      t.references :recorded_by,
                   null: false,
                   foreign_key: {
                     to_table: :users
                   }

      t.decimal :amount,
                precision: 15,
                scale: 2,
                null: false

      t.datetime :paid_at,
                 null: false

      t.string :reference
      t.text :notes

      t.timestamps
    end

    add_index :purchase_payments,
              %i[organization_id paid_at]

    add_check_constraint(
      :purchase_payments,
      "amount > 0",
      name: "purchase_payments_amount_positive"
    )
  end
end
