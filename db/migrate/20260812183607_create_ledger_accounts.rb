class CreateLedgerAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :ledger_accounts do |t|
      t.references :organization,
                   null: false,
                   foreign_key: true

      t.bigint :parent_id

      t.string :code,
               null: false

      t.string :name,
               null: false

      t.string :account_type,
               null: false

      t.string :normal_balance,
               null: false

      t.string :report_group,
               null: false

      t.boolean :postable,
                null: false,
                default: true

      t.boolean :active,
                null: false,
                default: true

      t.boolean :system_account,
                null: false,
                default: false

      t.timestamps
    end

    add_foreign_key :ledger_accounts,
                    :ledger_accounts,
                    column: :parent_id

    add_index :ledger_accounts,
              :parent_id

    add_index :ledger_accounts,
              %i[organization_id code],
              unique: true,
              name: "index_ledger_accounts_on_org_and_code"

    add_index :ledger_accounts,
              %i[organization_id account_type],
              name: "index_ledger_accounts_on_org_and_type"

    add_check_constraint(
      :ledger_accounts,
      <<~SQL.squish,
        account_type IN (
          'asset',
          'liability',
          'equity',
          'revenue',
          'expense'
        )
      SQL
      name: "ledger_accounts_account_type_check"
    )

    add_check_constraint(
      :ledger_accounts,
      "normal_balance IN ('debit', 'credit')",
      name: "ledger_accounts_normal_balance_check"
    )

    add_check_constraint(
      :ledger_accounts,
      <<~SQL.squish,
        report_group IN (
          'current_asset',
          'non_current_asset',
          'contra_asset',
          'current_liability',
          'non_current_liability',
          'equity',
          'revenue',
          'contra_revenue',
          'cost_of_sales',
          'operating_expense',
          'other_income',
          'other_expense'
        )
      SQL
      name: "ledger_accounts_report_group_check"
    )
  end
end
