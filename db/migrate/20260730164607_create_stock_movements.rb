class CreateStockMovements < ActiveRecord::Migration[8.1]
  def change
    create_table :stock_movements do |t|
      t.references :organization,
                   null: false,
                   foreign_key: true

      t.references :branch,
                   null: false,
                   foreign_key: true

      t.references :item,
                   null: false,
                   foreign_key: true

      t.references :recorded_by,
                   null: false,
                   foreign_key: {
                     to_table: :users
                   }

      t.string :movement_type,
               null: false

      t.decimal :quantity_change,
                precision: 15,
                scale: 4,
                null: false

      t.datetime :occurred_at,
                 null: false

      t.string :reference
      t.string :source_type
      t.bigint :source_id
      t.text :notes

      t.timestamps
    end

    add_index :stock_movements,
              %i[organization_id occurred_at],
              name: "index_stock_movements_on_org_and_time"

    add_index :stock_movements,
              %i[branch_id item_id occurred_at],
              name: "index_stock_movements_on_branch_item_and_time"

    add_index :stock_movements,
              %i[source_type source_id]

    add_index :stock_movements,
              %i[organization_id reference]

    add_check_constraint :stock_movements,
                         "quantity_change <> 0",
                         name: "stock_movements_nonzero_quantity"

    add_check_constraint :stock_movements,
                         <<~SQL.squish,
                           movement_type IN (
                             'opening',
                             'adjustment_in',
                             'adjustment_out',
                             'purchase',
                             'sale',
                             'sale_return',
                             'purchase_return',
                             'transfer_in',
                             'transfer_out'
                           )
                         SQL
                         name: "stock_movements_valid_type"

    add_check_constraint :stock_movements,
                         <<~SQL.squish,
                           (
                             movement_type IN (
                               'opening',
                               'adjustment_in',
                               'purchase',
                               'sale_return',
                               'transfer_in'
                             )
                             AND quantity_change > 0
                           )
                           OR
                           (
                             movement_type IN (
                               'adjustment_out',
                               'sale',
                               'purchase_return',
                               'transfer_out'
                             )
                             AND quantity_change < 0
                           )
                         SQL
                         name: "stock_movements_direction_matches_type"
  end
end
