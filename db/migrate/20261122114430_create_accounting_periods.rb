class CreateAccountingPeriods < ActiveRecord::Migration[8.1]
  def change
    create_table :accounting_periods do |t|
      t.references :organization,
                   null: false,
                   foreign_key: true

      t.string :name,
               null: false

      t.date :starts_on,
             null: false

      t.date :ends_on,
             null: false

      t.string :status,
               null: false,
               default: "open"

      t.datetime :closed_at

      t.references :closed_by,
                   null: true,
                   foreign_key: {
                     to_table: :users
                   }

      t.timestamps
    end

    add_index :accounting_periods,
              [
                :organization_id,
                :starts_on,
                :ends_on
              ],
              name:
                "index_accounting_periods_on_org_and_dates"

    add_index :accounting_periods,
              [
                :organization_id,
                :status
              ],
              name:
                "index_accounting_periods_on_org_and_status"

    add_check_constraint(
      :accounting_periods,
      "starts_on <= ends_on",
      name:
        "accounting_periods_valid_date_range"
    )

    add_check_constraint(
      :accounting_periods,
      "status IN ('open', 'closed')",
      name:
        "accounting_periods_valid_status"
    )
  end
end
