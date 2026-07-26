class CreateTaxRates < ActiveRecord::Migration[8.1]
  def change
    create_table :tax_rates do |t|
      t.references :organization,
                   null: false,
                   foreign_key: true

      t.string :name,
               null: false

      t.string :code,
               null: false

      t.decimal :rate,
                precision: 7,
                scale: 4,
                null: false,
                default: 0

      t.string :tax_type,
               null: false,
               default: "standard"

      t.boolean :active,
                null: false,
                default: true

      t.timestamps
    end

    add_index :tax_rates,
              %i[organization_id code],
              unique: true,
              name: "index_tax_rates_on_org_and_code"

    add_index :tax_rates,
              %i[organization_id name],
              unique: true,
              name: "index_tax_rates_on_org_and_name"

    add_index :tax_rates,
              %i[organization_id active]

    add_check_constraint :tax_rates,
                         "rate >= 0 AND rate <= 100",
                         name: "tax_rates_rate_range"
  end
end
