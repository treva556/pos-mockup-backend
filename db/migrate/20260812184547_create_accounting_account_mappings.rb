class CreateAccountingAccountMappings < ActiveRecord::Migration[8.1]
  def change
    create_table :accounting_account_mappings do |t|
      t.references :organization,
                   null: false,
                   foreign_key: true

      t.references :ledger_account,
                   null: false,
                   foreign_key: true

      t.string :role,
               null: false

      t.timestamps
    end

    add_index :accounting_account_mappings,
              %i[organization_id role],
              unique: true,
              name: "index_accounting_mappings_on_org_and_role"

    add_check_constraint(
      :accounting_account_mappings,
      <<~SQL.squish,
        role IN (
          'accounts_receivable',
          'inventory',
          'supplier_credit_receivable',
          'accounts_payable',
          'customer_refund_payable',
          'sales_revenue',
          'sales_returns',
          'cost_of_goods_sold',
          'input_tax',
          'output_tax',
          'retained_earnings',
          'opening_balance_equity',
          'inventory_adjustment_gain',
          'inventory_adjustment_loss'
        )
      SQL
      name: "accounting_account_mappings_role_check"
    )
  end
end
