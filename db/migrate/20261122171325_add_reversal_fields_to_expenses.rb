class AddReversalFieldsToExpenses < ActiveRecord::Migration[8.1]
  def change
    add_column :expenses,
               :status,
               :string,
               null: false,
               default: "posted"

    add_column :expenses,
               :reversed_at,
               :datetime

    add_reference :expenses,
                  :reversed_by,
                  null: true,
                  foreign_key: {
                    to_table: :users
                  }

    add_index :expenses,
              [
                :organization_id,
                :status
              ]

    add_check_constraint(
      :expenses,
      "status IN ('posted', 'reversed')",
      name: "expenses_valid_status"
    )
  end
end
