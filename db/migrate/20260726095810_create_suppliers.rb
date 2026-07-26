class CreateSuppliers < ActiveRecord::Migration[8.1]
  def change
      create_table :suppliers do |t|
        t.references :organization,
                    null: false,
                    foreign_key: true

        t.string :name, null: false
        t.string :contact_person
        t.string :phone
        t.string :email
        t.string :kra_pin

        t.text :address
        t.text :notes

        t.boolean :active,
                  null: false,
                  default: true

        t.integer :payment_terms_days,
                  null: false,
                  default: 0

        t.timestamps
      end

      add_index :suppliers,
                %i[organization_id name]

      add_index :suppliers,
                %i[organization_id active]

      add_index :suppliers,
                %i[organization_id kra_pin],
                unique: true,
                where: "kra_pin IS NOT NULL",
                name: "index_suppliers_on_org_and_kra_pin"
    end
end
