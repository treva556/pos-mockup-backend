class CreateItems < ActiveRecord::Migration[8.1]
  def change
    create_table :items do |t|
      t.references :organization,
                   null: false,
                   foreign_key: true

      t.references :product_category,
                   null: true,
                   foreign_key: true

      t.references :unit_of_measure,
                   null: false,
                   foreign_key: true

      t.references :tax_rate,
                   null: true,
                   foreign_key: true

      t.string :name,
               null: false

      t.text :description

      t.string :sku
      t.string :barcode

      t.string :item_type,
               null: false,
               default: "product"

      t.decimal :selling_price,
                precision: 15,
                scale: 2,
                null: false,
                default: 0

      t.decimal :purchase_cost,
                precision: 15,
                scale: 2,
                null: false,
                default: 0

      t.boolean :track_inventory,
                null: false,
                default: true

      t.boolean :active,
                null: false,
                default: true

      t.timestamps
    end

    add_index :items,
              %i[organization_id name]

    add_index :items,
              %i[organization_id active]

    add_index :items,
              %i[organization_id item_type]

    add_index :items,
              %i[organization_id sku],
              unique: true,
              where: "sku IS NOT NULL",
              name: "index_items_on_org_and_sku"

    add_index :items,
              %i[organization_id barcode],
              unique: true,
              where: "barcode IS NOT NULL",
              name: "index_items_on_org_and_barcode"

    add_check_constraint :items,
                         "selling_price >= 0",
                         name: "items_selling_price_nonnegative"

    add_check_constraint :items,
                         "purchase_cost >= 0",
                         name: "items_purchase_cost_nonnegative"

    add_check_constraint :items,
                         "item_type IN ('product', 'service')",
                         name: "items_valid_item_type"

    add_check_constraint :items,
                         <<~SQL.squish,
                           item_type = 'product' OR
                           track_inventory = FALSE
                         SQL
                         name: "services_cannot_track_inventory"
  end
end
