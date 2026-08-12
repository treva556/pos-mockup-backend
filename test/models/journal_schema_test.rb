require "test_helper"

class JournalSchemaTest <
  ActiveSupport::TestCase
  test "journal entry database safeguards exist" do
    connection =
      ActiveRecord::Base.connection

    indexes =
      connection
        .indexes(
          :journal_entries
        )
        .index_by(&:name)

    assert(
      indexes.fetch(
        "index_journal_entries_on_org_and_number"
      ).unique
    )

    assert(
      indexes.fetch(
        "index_journal_entries_on_org_and_sequence"
      ).unique
    )

    assert(
      indexes.fetch(
        "index_journal_entries_on_unique_source"
      ).unique
    )

    assert(
      indexes.fetch(
        "index_journal_entries_on_unique_reversal"
      ).unique
    )

    constraints =
      connection
        .check_constraints(
          :journal_entries
        )
        .map(&:name)

    assert_includes(
      constraints,
      "journal_entries_status_check"
    )

    assert_includes(
      constraints,
      "journal_entries_positive_sequence"
    )
  end

  test "journal line database safeguards exist" do
    connection =
      ActiveRecord::Base.connection

    indexes =
      connection
        .indexes(
          :journal_lines
        )
        .index_by(&:name)

    assert(
      indexes.fetch(
        "index_journal_lines_on_entry_and_line"
      ).unique
    )

    constraints =
      connection
        .check_constraints(
          :journal_lines
        )
        .map(&:name)

    %w[
      journal_lines_positive_line_number
      journal_lines_nonnegative_debit
      journal_lines_nonnegative_credit
      journal_lines_one_sided_amount
    ].each do |constraint|
      assert_includes(
        constraints,
        constraint
      )
    end
  end
end
