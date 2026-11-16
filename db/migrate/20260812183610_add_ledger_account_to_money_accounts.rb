class AddLedgerAccountToMoneyAccounts < ActiveRecord::Migration[8.1]
  def change
    add_reference :money_accounts,
                  :ledger_account,
                  null: true,
                  foreign_key: true,
                  index: true
  end
end
