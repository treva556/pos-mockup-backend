class CreateUnitOfMeasures < ActiveRecord::Migration[8.1]
  def change
    create_table :unit_of_measures do |t|
      t.references :organization,
                   null: false,
                   foreign_key: true

      t.string :name,
               null: false

      t.string :symbol,
               null: false

      t.boolean :decimal_allowed,
                null: false,
                default: false

      t.boolean :active,
                null: false,
                default: true

      t.timestamps
    end

    add_index :unit_of_measures,
              %i[organization_id name],
              unique: true,
              name: "index_units_on_org_and_name"

    add_index :unit_of_measures,
              %i[organization_id symbol],
              unique: true,
              name: "index_units_on_org_and_symbol"

    add_index :unit_of_measures,
              %i[organization_id active]
  end
end
