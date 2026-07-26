class CreateMoneyAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :money_accounts do |t|
      t.references :organization,
                   null: false,
                   foreign_key: true

      t.references :branch,
                   null: true,
                   foreign_key: true

      t.string :name,
               null: false

      t.string :account_type,
               null: false,
               default: "cash"

      t.string :account_number

      t.decimal :opening_balance,
                precision: 15,
                scale: 2,
                null: false,
                default: 0

      t.date :opening_balance_date

      t.boolean :can_receive,
                null: false,
                default: true

      t.boolean :can_pay,
                null: false,
                default: true

      t.boolean :active,
                null: false,
                default: true

      t.text :notes

      t.timestamps
    end

    add_index :money_accounts,
              %i[organization_id name],
              unique: true,
              name: "index_money_accounts_on_org_and_name"

    add_index :money_accounts,
              %i[organization_id account_number],
              unique: true,
              where: "account_number IS NOT NULL",
              name: "index_money_accounts_on_org_and_number"

    add_index :money_accounts,
              %i[organization_id account_type]

    add_index :money_accounts,
              %i[organization_id branch_id]

    add_index :money_accounts,
              %i[organization_id active]

    add_check_constraint :money_accounts,
                         <<~SQL.squish,
                           account_type IN (
                             'cash',
                             'petty_cash',
                             'mpesa_till',
                             'mpesa_paybill',
                             'bank',
                             'card_clearing',
                             'mobile_wallet',
                             'other'
                           )
                         SQL
                         name: "money_accounts_valid_account_type"
  end
end
