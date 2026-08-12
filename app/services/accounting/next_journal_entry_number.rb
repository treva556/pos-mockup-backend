module Accounting
  class NextJournalEntryNumber
    Result =
      Data.define(
        :sequence_number,
        :entry_number
      )

    def self.call(organization:)
      new(
        organization: organization
      ).call
    end

    def initialize(organization:)
      @organization =
        organization
    end

    def call
      sequence_number =
        organization
          .journal_entries
          .maximum(
            :sequence_number
          )
          .to_i + 1

      Result.new(
        sequence_number:
          sequence_number,
        entry_number:
          format(
            "JE-%06d",
            sequence_number
          )
      )
    end

    private

    attr_reader :organization
  end
end
