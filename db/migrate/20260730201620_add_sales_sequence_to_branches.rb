class AddSalesSequenceToBranches <
  ActiveRecord::Migration[8.1]
  def change
    add_column :branches,
               :next_sale_sequence,
               :bigint,
               null: false,
               default: 1

    add_check_constraint :branches,
                         "next_sale_sequence > 0",
                         name: "branches_positive_sale_sequence"
  end
end
