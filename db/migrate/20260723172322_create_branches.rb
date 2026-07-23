class CreateBranches < ActiveRecord::Migration[7.2]
  def change
    create_table :branches do |t|
      t.references :organization,
                   null: false,
                   foreign_key: true

      t.string :name, null: false
      t.string :code, null: false

      t.string :phone
      t.string :email
      t.text :address

      t.boolean :active, null: false, default: true
      t.boolean :main, null: false, default: false

      t.timestamps
    end

    add_index :branches,
              [:organization_id, :code],
              unique: true
  end
end