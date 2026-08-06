class AddInventoryBatchExpiryTracking <
  ActiveRecord::Migration[8.1]
  def change
    add_column :items,
               :tracks_expiry,
               :boolean,
               null: false,
               default: false

    create_table :inventory_batches do |t|
      t.references :organization,
                   null: false,
                   foreign_key: true

      t.references :branch,
                   null: false,
                   foreign_key: true

      t.references :item,
                   null: false,
                   foreign_key: true

      t.references :purchase_line,
                   null: true,
                   foreign_key: true

      t.string :batch_number

      t.date :manufactured_on

      t.date :expires_on,
             null: false

      t.decimal :quantity_received,
                precision: 15,
                scale: 4,
                null: false

      t.decimal :quantity_remaining,
                precision: 15,
                scale: 4,
                null: false

      t.decimal :unit_cost,
                precision: 15,
                scale: 2,
                null: false

      t.datetime :received_at,
                 null: false

      t.string :status,
               null: false,
               default: "active"

      t.timestamps
    end

    add_index :inventory_batches,
              %i[
                organization_id
                branch_id
                item_id
                expires_on
              ],
              name: "index_batches_for_expiry_lookup"

    add_index :inventory_batches,
              %i[
                organization_id
                branch_id
                item_id
                batch_number
              ],
              unique: true,
              where:
                "batch_number IS NOT NULL " \
                "AND batch_number <> ''",
              name: "index_unique_inventory_batch_number"

    add_index :inventory_batches,
              %i[
                organization_id
                status
                expires_on
              ],
              name: "index_batches_for_expiry_reports"

    add_check_constraint(
      :inventory_batches,
      "quantity_received > 0",
      name:
        "inventory_batches_received_quantity_positive"
    )

    add_check_constraint(
      :inventory_batches,
      "quantity_remaining >= 0",
      name:
        "inventory_batches_remaining_quantity_nonnegative"
    )

    add_check_constraint(
      :inventory_batches,
      "quantity_remaining <= quantity_received",
      name:
        "inventory_batches_remaining_not_above_received"
    )

    add_check_constraint(
      :inventory_batches,
      "unit_cost >= 0",
      name:
        "inventory_batches_unit_cost_nonnegative"
    )

    add_check_constraint(
      :inventory_batches,
      "status IN ('active', 'quarantined', 'depleted')",
      name:
        "inventory_batches_status_valid"
    )

    add_check_constraint(
      :inventory_batches,
      <<~SQL.squish,
        manufactured_on IS NULL OR
        manufactured_on <= expires_on
      SQL
      name:
        "inventory_batches_manufacture_before_expiry"
    )

    add_reference :stock_movements,
                  :inventory_batch,
                  null: true,
                  foreign_key: true,
                  index: true
  end
end
