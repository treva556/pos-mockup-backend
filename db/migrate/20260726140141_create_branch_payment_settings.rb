class CreateBranchPaymentSettings <
  ActiveRecord::Migration[8.1]
  def change
    create_table :branch_payment_settings do |t|
      t.references :organization,
                   null: false,
                   foreign_key: true

      t.references :branch,
                   null: false,
                   foreign_key: true

      t.references :payment_method,
                   null: false,
                   foreign_key: true

      t.references :money_account,
                   null: true,
                   foreign_key: true

      t.boolean :enabled,
                null: false,
                default: true

      t.timestamps
    end

    add_index :branch_payment_settings,
              %i[branch_id payment_method_id],
              unique: true,
              name: "index_branch_payment_settings_on_branch_and_method"

    add_index :branch_payment_settings,
              %i[organization_id enabled]
  end
end
