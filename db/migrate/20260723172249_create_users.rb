class CreateUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :password_digest, null: false

      # Platform-level role, not the user's role inside a company.
      t.string :platform_role, null: false, default: "regular"
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :users, :email, unique: true
  end
end