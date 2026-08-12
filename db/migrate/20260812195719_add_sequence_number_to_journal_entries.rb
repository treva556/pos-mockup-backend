class AddSequenceNumberToJournalEntries <
  ActiveRecord::Migration[8.1]
  def change
    add_column :journal_entries,
               :sequence_number,
               :integer

    add_index :journal_entries,
              %i[
                organization_id
                sequence_number
              ],
              unique: true,
              name:
                "index_journal_entries_on_org_and_sequence"

    add_check_constraint(
      :journal_entries,
      "sequence_number IS NULL OR sequence_number > 0",
      name:
        "journal_entries_positive_sequence"
    )
  end
end
