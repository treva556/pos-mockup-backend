class CreateSales < ActiveRecord::Migration[8.1]
  def change
    create_table :sales do |t|
      t.references :organization,
                   null: false,
                   foreign_key: true

      t.references :branch,
                   null: false,
                   foreign_key: true

      t.references :customer,
                   null: true,
                   foreign_key: true

      t.references :cashier,
                   null: false,
                   foreign_key: {
                     to_table: :users
                   }

      t.string :sale_number,
               null: false

      t.string :status,
               null: false,
               default: "draft"

      t.string :payment_status,
               null: false,
               default: "unpaid"

      t.datetime :sold_at
      t.datetime :cancelled_at

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

      t.decimal :change_given,
                precision: 15,
                scale: 2,
                null: false,
                default: 0

      t.text :notes

      t.timestamps
    end

    add_index :sales,
              %i[organization_id sale_number],
              unique: true,
              name: "index_sales_on_org_and_sale_number"

    add_index :sales,
              %i[organization_id sold_at],
              name: "index_sales_on_org_and_sold_at"

    add_index :sales,
              %i[branch_id sold_at],
              name: "index_sales_on_branch_and_sold_at"

    add_index :sales,
              %i[customer_id sold_at],
              name: "index_sales_on_customer_and_sold_at"

    add_index :sales,
              %i[organization_id status]

    add_index :sales,
              %i[organization_id payment_status]

    add_check_constraint :sales,
                         <<~SQL.squish,
                           status IN (
                             'draft',
                             'completed',
                             'cancelled'
                           )
                         SQL
                         name: "sales_allowed_status"

    add_check_constraint :sales,
                         <<~SQL.squish,
                           payment_status IN (
                             'unpaid',
                             'partially_paid',
                             'paid'
                           )
                         SQL
                         name: "sales_allowed_payment_status"

    add_check_constraint :sales,
                         "subtotal >= 0",
                         name: "sales_nonnegative_subtotal"

    add_check_constraint :sales,
                         "discount_total >= 0",
                         name: "sales_nonnegative_discount"

    add_check_constraint :sales,
                         "tax_total >= 0",
                         name: "sales_nonnegative_tax"

    add_check_constraint :sales,
                         "total >= 0",
                         name: "sales_nonnegative_total"

    add_check_constraint :sales,
                         "amount_paid >= 0",
                         name: "sales_nonnegative_amount_paid"

    add_check_constraint :sales,
                         "balance_due >= 0",
                         name: "sales_nonnegative_balance_due"

    add_check_constraint :sales,
                         "change_given >= 0",
                         name: "sales_nonnegative_change"

    add_check_constraint :sales,
                         "discount_total <= subtotal",
                         name: "sales_discount_within_subtotal"

    add_check_constraint :sales,
                         "tax_total <= total",
                         name: "sales_tax_within_total"

    add_check_constraint :sales,
                         "amount_paid <= total",
                         name: "sales_payment_within_total"

    add_check_constraint :sales,
                         "amount_paid + balance_due = total",
                         name: "sales_payment_balance_matches_total"
  end
end
