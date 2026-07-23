class CreateMemberships < ActiveRecord::Migration[7.2]
  def change
    create_table :memberships do |t|
      t.references :user,
                   null: false,
                   foreign_key: true

      t.references :organization,
                   null: false,
                   foreign_key: true

      # Optional for now:
      # nil means the owner/admin can operate across the organization.
      t.references :branch,
                   null: true,
                   foreign_key: true

      t.string :role, null: false, default: "cashier"
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :memberships,
              [:user_id, :organization_id],
              unique: true
  end
end