class CreateStockTransfers < ActiveRecord::Migration[8.1]
  def change
    create_table :stock_transfers do |t|
      t.references :organization,
                   null: false,
                   foreign_key: true

      t.bigint :from_branch_id,
               null: false

      t.bigint :to_branch_id,
               null: false

      t.references :item,
                   null: false,
                   foreign_key: true

      t.references :recorded_by,
                   null: false,
                   foreign_key: {
                     to_table: :users
                   }

      t.decimal :quantity,
                precision: 15,
                scale: 4,
                null: false

      t.datetime :transferred_at,
                 null: false

      t.string :reference
      t.text :notes

      t.timestamps
    end

    add_foreign_key :stock_transfers,
                    :branches,
                    column: :from_branch_id

    add_foreign_key :stock_transfers,
                    :branches,
                    column: :to_branch_id

    add_index :stock_transfers,
              :from_branch_id

    add_index :stock_transfers,
              :to_branch_id

    add_index :stock_transfers,
              %i[organization_id transferred_at],
              name: "index_stock_transfers_on_org_and_time"

    add_index :stock_transfers,
              %i[organization_id item_id]

    add_index :stock_transfers,
              %i[organization_id reference]

    add_check_constraint :stock_transfers,
                         "quantity > 0",
                         name: "stock_transfers_positive_quantity"

    add_check_constraint :stock_transfers,
                         "from_branch_id <> to_branch_id",
                         name: "stock_transfers_different_branches"
  end
end
