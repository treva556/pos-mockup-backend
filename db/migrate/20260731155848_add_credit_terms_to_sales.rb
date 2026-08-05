class AddCreditTermsToSales <
  ActiveRecord::Migration[8.1]
  def change
    add_column :sales,
               :due_on,
               :date

    add_index :sales,
              %i[organization_id due_on]

    add_check_constraint :sales,
                         <<~SQL.squish,
                           due_on IS NULL OR
                           sold_at IS NULL OR
                           due_on >= sold_at::date
                         SQL
                         name: "sales_due_date_not_before_sale"
  end
end
