class CreateOrganizations < ActiveRecord::Migration[7.2]
  def change
    create_table :organizations do |t|
      t.string :name, null: false
      t.string :legal_name
      t.string :phone
      t.string :email

      t.string :country_code, null: false, default: "KE"
      t.string :currency_code, null: false, default: "KES"
      t.string :time_zone, null: false, default: "Africa/Nairobi"

      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :organizations, :name
  end
end