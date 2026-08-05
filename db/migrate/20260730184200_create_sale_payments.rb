class CreateSalePayments < ActiveRecord::Migration[8.1]
  def change
    create_table :sale_payments do |t|
      t.references :organization,
                   null: false,
                   foreign_key: true

      t.references :sale,
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

      t.decimal :amount_tendered,
                precision: 15,
                scale: 2,
                null: false

      t.decimal :change_given,
                precision: 15,
                scale: 2,
                null: false,
                default: 0

      t.datetime :paid_at,
                 null: false

      t.string :reference
      t.text :notes

      t.timestamps
    end

    add_index :sale_payments,
              %i[sale_id paid_at]

    add_index :sale_payments,
              %i[organization_id paid_at]

    add_index :sale_payments,
              %i[organization_id payment_method_id],
              name: "index_sale_payments_on_org_and_method"

    add_index :sale_payments,
              %i[organization_id money_account_id],
              name: "index_sale_payments_on_org_and_account"

    add_index :sale_payments,
              %i[organization_id reference]

    add_check_constraint :sale_payments,
                         "amount > 0",
                         name: "sale_payments_positive_amount"

    add_check_constraint :sale_payments,
                         "amount_tendered >= amount",
                         name: "sale_payments_tendered_covers_amount"

    add_check_constraint :sale_payments,
                         "change_given >= 0",
                         name: "sale_payments_nonnegative_change"

    add_check_constraint :sale_payments,
                         "change_given = amount_tendered - amount",
                         name: "sale_payments_change_matches_tendered"
  end
end
