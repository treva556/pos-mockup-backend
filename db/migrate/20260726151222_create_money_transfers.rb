class CreateMoneyTransfers < ActiveRecord::Migration[8.1]
  def change
    create_table :money_transfers do |t|
      t.references :organization,
                   null: false,
                   foreign_key: true

      t.bigint :from_money_account_id,
               null: false

      t.bigint :to_money_account_id,
               null: false

      t.references :recorded_by,
                   null: false,
                   foreign_key: {
                     to_table: :users
                   }

      t.decimal :amount,
                precision: 15,
                scale: 2,
                null: false

      t.datetime :transferred_at,
                 null: false

      t.string :reference
      t.text :notes

      t.timestamps
    end

    add_foreign_key :money_transfers,
                    :money_accounts,
                    column: :from_money_account_id

    add_foreign_key :money_transfers,
                    :money_accounts,
                    column: :to_money_account_id

    add_index :money_transfers,
              :from_money_account_id

    add_index :money_transfers,
              :to_money_account_id

    add_index :money_transfers,
              %i[organization_id transferred_at]

    add_index :money_transfers,
              %i[organization_id reference]

    add_check_constraint :money_transfers,
                         "amount > 0",
                         name:
                           "money_transfers_positive_amount"

    add_check_constraint :money_transfers,
                         <<~SQL.squish,
                           from_money_account_id <>
                           to_money_account_id
                         SQL
                         name:
                           "money_transfers_different_accounts"
  end
end
