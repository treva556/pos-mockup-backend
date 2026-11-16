module Accounting
  class CreateJournalEntry
    def self.call(
      organization:,
      created_by:,
      entry_date:,
      description:,
      lines:,
      source: nil,
      reversal_of: nil,
      post: true
    )
      new(
        organization: organization,
        created_by: created_by,
        entry_date: entry_date,
        description: description,
        lines: lines,
        source: source,
        reversal_of: reversal_of,
        post: post
      ).call
    end

    def initialize(
      organization:,
      created_by:,
      entry_date:,
      description:,
      lines:,
      source:,
      reversal_of:,
      post:
    )
      @organization =
        organization

      @created_by =
        created_by

      @entry_date =
        entry_date

      @description =
        description

      @lines =
        lines

      @source =
        source

      @reversal_of =
        reversal_of

      @post =
        post
    end

    def call
      JournalEntry.transaction do
        journal_entry =
          create_entry_with_number!

        create_lines!(
          journal_entry
        )

        if post
          Accounting::PostJournalEntry.call(
            journal_entry: journal_entry
          )
        else
          journal_entry
        end
      end
    end

    private

    attr_reader :organization,
                :created_by,
                :entry_date,
                :description,
                :lines,
                :source,
                :reversal_of,
                :post

    def create_entry_with_number!
      organization.with_lock do
        numbering =
          Accounting::NextJournalEntryNumber
            .call(
              organization: organization
            )

        organization
          .journal_entries
          .create!(
            created_by: created_by,
            source: source,
            reversal_of: reversal_of,
            sequence_number:
              numbering.sequence_number,
            entry_number:
              numbering.entry_number,
            entry_date: entry_date,
            description: description,
            status: "draft"
          )
      end
    end

    def create_lines!(journal_entry)
      lines.each_with_index do |attributes, index|
        journal_entry
          .journal_lines
          .create!(
            {
              organization:
                organization,
              line_number:
                index + 1
            }.merge(
              attributes
            )
          )
      end
    end
  end
end
