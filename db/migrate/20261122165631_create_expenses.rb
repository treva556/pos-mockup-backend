class CreateExpenses < ActiveRecord::Migration[8.1]
  def change
    create_table :expenses do |t|
      t.references :organization,
                   null: false,
                   foreign_key: true

      t.references :branch,
                   null: true,
                   foreign_key: true

      t.references :expense_account,
                   null: false,
                   foreign_key: {
                     to_table: :ledger_accounts
                   }

      t.references :money_account,
                   null: false,
                   foreign_key: true

      t.references :recorded_by,
                   null: false,
                   foreign_key: {
                     to_table: :users
                   }

      t.date :expense_date,
             null: false

      t.decimal :amount,
                precision: 15,
                scale: 2,
                null: false

      t.string :payee
      t.string :reference
      t.text :notes

      t.timestamps
    end

    add_index :expenses,
              [
                :organization_id,
                :expense_date
              ]

    add_index :expenses,
              [
                :organization_id,
                :expense_account_id
              ],
              name:
                "index_expenses_on_org_and_expense_account"

    add_check_constraint(
      :expenses,
      "amount > 0",
      name:
        "expenses_positive_amount"
    )
  end
end
