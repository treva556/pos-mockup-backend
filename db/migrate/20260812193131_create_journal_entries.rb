class CreateJournalEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :journal_entries do |t|
      t.references :organization,
                   null: false,
                   foreign_key: true

      t.references :created_by,
                   null: false,
                   foreign_key: {
                     to_table: :users
                   }

      t.references :source,
                   polymorphic: true,
                   null: true

      t.string :entry_number,
               null: false

      t.date :entry_date,
             null: false

      t.string :status,
               null: false,
               default: "draft"

      t.string :description

      t.datetime :posted_at

      t.datetime :reversed_at

      t.timestamps
    end

    add_index :journal_entries,
              %i[
                organization_id
                entry_number
              ],
              unique: true,
              name:
                "index_journal_entries_on_org_and_number"

    add_index :journal_entries,
              %i[
                organization_id
                entry_date
              ],
              name:
                "index_journal_entries_on_org_and_date"

    add_index :journal_entries,
              %i[
                organization_id
                status
              ],
              name:
                "index_journal_entries_on_org_and_status"

    add_index :journal_entries,
              %i[
                organization_id
                source_type
                source_id
              ],
              unique: true,
              where:
                "source_type IS NOT NULL " \
                "AND source_id IS NOT NULL",
              name:
                "index_journal_entries_on_unique_source"

    add_check_constraint(
      :journal_entries,
      "status IN ('draft', 'posted', 'reversed')",
      name:
        "journal_entries_status_check"
    )
  end
end
