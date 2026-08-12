require "test_helper"

class JournalEntryTest <
  ActiveSupport::TestCase
  setup do
    @user =
      create_user

    @organization =
      provision_organization_for(
        @user
      )
  end

  test "valid draft journal entry" do
    entry =
      build_entry

    assert entry.valid?
  end

  test "normalizes entry number and description" do
    entry =
      build_entry(
        entry_number: "  je-000001  ",
        description: "  Opening entry  "
      )

    entry.validate

    assert_equal(
      "JE-000001",
      entry.entry_number
    )

    assert_equal(
      "Opening entry",
      entry.description
    )
  end

  test "entry number is unique within organization" do
    build_entry.save!

    duplicate =
      build_entry

    assert_not duplicate.valid?

    assert_includes(
      duplicate.errors[:entry_number],
      "has already been taken"
    )
  end

  test "same entry number may exist in another organization" do
    build_entry.save!

    other_user =
      create_user

    other_organization =
      provision_organization_for(
        other_user
      )

    entry =
      build_entry(
        organization:
          other_organization,
        created_by:
          other_user
      )

    assert entry.valid?
  end

  test "created by must be active organization member" do
    outsider =
      create_user

    entry =
      build_entry(
        created_by: outsider
      )

    assert_not entry.valid?

    assert_includes(
      entry.errors[:created_by],
      "must be an active organization member"
    )
  end

  test "source must belong to same organization" do
    other_user =
      create_user

    other_organization =
      provision_organization_for(
        other_user
      )

    foreign_sale =
      Sale.new(
        organization:
          other_organization
      )

    entry =
      build_entry(
        source: foreign_sale
      )

    assert_not entry.valid?

    assert_includes(
      entry.errors[:source],
      "must belong to the same organization"
    )
  end

  test "balanced reports true for equal debits and credits" do
    entry =
      build_entry

    entry.save!

    debit_account =
      @organization
        .ledger_accounts
        .find_by!(
          code: "1100"
        )

    credit_account =
      @organization
        .ledger_accounts
        .find_by!(
          code: "4010"
        )

    entry.journal_lines.create!(
      organization: @organization,
      ledger_account: debit_account,
      branch: @organization.main_branch,
      line_number: 1,
      debit: 1_000,
      credit: 0
    )

    entry.journal_lines.create!(
      organization: @organization,
      ledger_account: credit_account,
      branch: @organization.main_branch,
      line_number: 2,
      debit: 0,
      credit: 1_000
    )

    assert entry.balanced?

    assert_equal(
      1_000.to_d,
      entry.total_debits
    )

    assert_equal(
      1_000.to_d,
      entry.total_credits
    )
  end

  private

  def build_entry(
    organization: @organization,
    created_by: @user,
    entry_number: "JE-000001",
    description: "Test journal",
    source: nil
  )
    JournalEntry.new(
      organization: organization,
      created_by: created_by,
      source: source,
      entry_number: entry_number,
      entry_date: Date.current,
      status: "draft",
      description: description
    )
  end
end
