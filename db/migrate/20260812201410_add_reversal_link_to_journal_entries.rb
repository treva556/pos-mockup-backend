class AddReversalLinkToJournalEntries <
  ActiveRecord::Migration[8.1]
  def change
    add_reference :journal_entries,
                  :reversal_of,
                  null: true,
                  foreign_key: {
                    to_table: :journal_entries
                  }

    add_index :journal_entries,
              :reversal_of_id,
              unique: true,
              where:
                "reversal_of_id IS NOT NULL",
              name:
                "index_journal_entries_on_unique_reversal"
  end
end
