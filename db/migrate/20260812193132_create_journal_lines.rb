class CreateJournalLines < ActiveRecord::Migration[8.1]
  def change
    create_table :journal_lines do |t|
      t.references :organization,
                   null: false,
                   foreign_key: true

      t.references :journal_entry,
                   null: false,
                   foreign_key: true

      t.references :ledger_account,
                   null: false,
                   foreign_key: true

      t.references :branch,
                   null: true,
                   foreign_key: true

      t.integer :line_number,
                null: false

      t.decimal :debit,
                precision: 15,
                scale: 2,
                null: false,
                default: 0

      t.decimal :credit,
                precision: 15,
                scale: 2,
                null: false,
                default: 0

      t.string :description

      t.timestamps
    end

    add_index :journal_lines,
              %i[
                journal_entry_id
                line_number
              ],
              unique: true,
              name:
                "index_journal_lines_on_entry_and_line"

    add_index :journal_lines,
              %i[
                organization_id
                ledger_account_id
              ],
              name:
                "index_journal_lines_on_org_and_account"

    add_index :journal_lines,
              %i[
                organization_id
                branch_id
              ],
              name:
                "index_journal_lines_on_org_and_branch"

    add_check_constraint(
      :journal_lines,
      "line_number > 0",
      name:
        "journal_lines_positive_line_number"
    )

    add_check_constraint(
      :journal_lines,
      "debit >= 0",
      name:
        "journal_lines_nonnegative_debit"
    )

    add_check_constraint(
      :journal_lines,
      "credit >= 0",
      name:
        "journal_lines_nonnegative_credit"
    )

    add_check_constraint(
      :journal_lines,
      <<~SQL.squish,
        (
          debit > 0
          AND credit = 0
        )
        OR
        (
          credit > 0
          AND debit = 0
        )
      SQL
      name:
        "journal_lines_one_sided_amount"
    )
  end
end
