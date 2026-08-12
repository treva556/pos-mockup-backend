module Accounting
  class ReverseJournalEntry
    class ReversalError < StandardError; end

    def self.call(
      journal_entry:,
      reversed_by:,
      reversal_date: Date.current,
      description: nil
    )
      new(
        journal_entry: journal_entry,
        reversed_by: reversed_by,
        reversal_date: reversal_date,
        description: description
      ).call
    end

    def initialize(
      journal_entry:,
      reversed_by:,
      reversal_date:,
      description:
    )
      @journal_entry =
        journal_entry

      @reversed_by =
        reversed_by

      @reversal_date =
        reversal_date

      @description =
        description
    end

    def call
      JournalEntry.transaction do
        journal_entry.lock!

        validate_reversal!

        reversal_entry =
          Accounting::CreateJournalEntry.call(
            organization:
              journal_entry.organization,
            created_by:
              reversed_by,
            entry_date:
              reversal_date,
            description:
              reversal_description,
            source: nil,
            reversal_of:
              journal_entry,
            lines:
              reversal_lines,
            post: true
          )

        mark_original_reversed!

        reversal_entry
      end
    end

    private

    attr_reader :journal_entry,
                :reversed_by,
                :reversal_date,
                :description

    def validate_reversal!
      unless journal_entry.status_posted?
        raise ReversalError,
              "Only posted journal entries can be reversed"
      end

      if journal_entry.reversal_of.present?
        raise ReversalError,
              "A reversal journal cannot itself be reversed"
      end

      if journal_entry.reversal_entry.present?
        raise ReversalError,
              "Journal entry has already been reversed"
      end

      unless active_organization_member?
        raise ReversalError,
              "Reversing user must be an active organization member"
      end

      return unless reversal_date <
                    journal_entry.entry_date

      raise ReversalError,
            "Reversal date cannot be before the original entry date"
    end

    def active_organization_member?
      return false if reversed_by.blank?

      journal_entry
        .organization
        .memberships
        .active
        .exists?(
          user_id: reversed_by.id
        )
    end

    def reversal_description
      description
        .to_s
        .strip
        .presence ||
        "Reversal of #{journal_entry.entry_number}"
    end

    def reversal_lines
      journal_entry
        .journal_lines
        .ordered
        .map do |line|
          {
            ledger_account:
              line.ledger_account,
            branch:
              line.branch,
            debit:
              line.credit,
            credit:
              line.debit,
            description:
              line.description
          }
        end
    end

    def mark_original_reversed!
      now =
        Time.current

      journal_entry.update_columns(
        status: "reversed",
        reversed_at: now,
        updated_at: now
      )
    end
  end
end
