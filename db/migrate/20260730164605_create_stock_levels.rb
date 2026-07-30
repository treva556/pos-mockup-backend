class CreateStockLevels < ActiveRecord::Migration[8.1]
  def change
    create_table :stock_levels do |t|
      t.references :organization,
                   null: false,
                   foreign_key: true

      t.references :branch,
                   null: false,
                   foreign_key: true

      t.references :item,
                   null: false,
                   foreign_key: true

      t.decimal :quantity_on_hand,
                precision: 15,
                scale: 4,
                null: false,
                default: 0

      t.decimal :reorder_level,
                precision: 15,
                scale: 4,
                null: false,
                default: 0

      t.datetime :last_movement_at

      t.timestamps
    end

    add_index :stock_levels,
              %i[organization_id branch_id item_id],
              unique: true,
              name: "index_stock_levels_on_org_branch_and_item"

    add_index :stock_levels,
              %i[organization_id branch_id]

    add_index :stock_levels,
              %i[organization_id item_id]

    add_check_constraint :stock_levels,
                         "quantity_on_hand >= 0",
                         name: "stock_levels_nonnegative_quantity"

    add_check_constraint :stock_levels,
                         "reorder_level >= 0",
                         name: "stock_levels_nonnegative_reorder_level"
  end
end
