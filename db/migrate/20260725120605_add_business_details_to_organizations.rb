class AddBusinessDetailsToOrganizations < ActiveRecord::Migration[7.2]
  def change
    add_column :organizations, :address, :text
    add_column :organizations, :registration_number, :string
    add_column :organizations, :kra_pin, :string

    add_column :organizations,
               :vat_registered,
               :boolean,
               null: false,
               default: false

    add_column :organizations, :receipt_footer, :text

    add_index :organizations,
              :kra_pin,
              unique: true,
              where: "kra_pin IS NOT NULL",
              name: "index_organizations_on_unique_kra_pin"
  end
end
