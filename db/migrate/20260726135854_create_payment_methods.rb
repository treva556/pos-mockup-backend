class CreatePaymentMethods < ActiveRecord::Migration[8.1]
  def change
    create_table :payment_methods do |t|
      t.references :organization,
                   null: false,
                   foreign_key: true

      t.string :name,
               null: false

      t.string :code,
               null: false

      t.string :payment_type,
               null: false,
               default: "cash"

      t.boolean :requires_reference,
                null: false,
                default: false

      t.boolean :active,
                null: false,
                default: true

      t.timestamps
    end

    add_index :payment_methods,
              %i[organization_id name],
              unique: true,
              name: "index_payment_methods_on_org_and_name"

    add_index :payment_methods,
              %i[organization_id code],
              unique: true,
              name: "index_payment_methods_on_org_and_code"

    add_index :payment_methods,
              %i[organization_id payment_type]

    add_index :payment_methods,
              %i[organization_id active]

    add_check_constraint :payment_methods,
                         <<~SQL.squish,
                           payment_type IN (
                             'cash',
                             'mobile_money',
                             'bank_transfer',
                             'card',
                             'credit',
                             'other'
                           )
                         SQL
                         name: "payment_methods_valid_payment_type"
  end
end
