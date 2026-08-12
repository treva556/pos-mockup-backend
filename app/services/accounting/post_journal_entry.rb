module Accounting
  class PostJournalEntry
    class PostingError < StandardError; end

    def self.call(journal_entry:)
      new(
        journal_entry: journal_entry
      ).call
    end

    def initialize(journal_entry:)
      @journal_entry =
        journal_entry
    end

    def call
      JournalEntry.transaction do
        journal_entry.lock!

        validate_draft!
        validate_entry!
        validate_lines!
        validate_balance!

        mark_posted!

        journal_entry
      end
    end

    private

    attr_reader :journal_entry

    def validate_draft!
      return if journal_entry.status_draft?

      raise PostingError,
            "Only draft journal entries can be posted"
    end

    def validate_entry!
      return if journal_entry.valid?

      raise PostingError,
            journal_entry
              .errors
              .full_messages
              .to_sentence
    end

    def validate_lines!
      lines =
        journal_entry
          .journal_lines
          .reload

      if lines.size < 2
        raise PostingError,
              "Journal entry must contain at least two lines"
      end

      invalid_line =
        lines.find do |line|
          !line.valid?
        end

      return unless invalid_line

      raise PostingError,
            invalid_line
              .errors
              .full_messages
              .to_sentence
    end

    def validate_balance!
      debits =
        journal_entry.total_debits

      credits =
        journal_entry.total_credits

      if debits.zero?
        raise PostingError,
              "Journal entry total must be greater than zero"
      end

      return if debits == credits

      raise PostingError,
            "Journal entry debits must equal credits"
    end

    def mark_posted!
      now =
        Time.current

      journal_entry.update_columns(
        status: "posted",
        posted_at: now,
        updated_at: now
      )
    end
  end
end
