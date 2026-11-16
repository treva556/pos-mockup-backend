class AddAccountingEnabledToOrganizations <
  ActiveRecord::Migration[8.1]
  def change
    add_column :organizations,
               :accounting_enabled,
               :boolean,
               null: false,
               default: false
  end
end
