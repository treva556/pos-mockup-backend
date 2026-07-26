class CreateProductCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :product_categories do |t|
      t.references :organization,
                   null: false,
                   foreign_key: true

      t.string :name,
               null: false

      t.text :description

      t.boolean :active,
                null: false,
                default: true

      t.timestamps
    end

    add_index :product_categories,
              %i[organization_id name],
              unique: true,
              name: "index_product_categories_on_org_and_name"

    add_index :product_categories,
              %i[organization_id active]
  end
end
