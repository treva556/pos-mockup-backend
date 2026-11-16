require "test_helper"

class JournalLineTest <
  ActiveSupport::TestCase
  setup do
    @user =
      create_user

    @organization =
      provision_organization_for(
        @user
      )

    @entry =
      JournalEntry.create!(
        organization: @organization,
        created_by: @user,
        entry_number: "JE-000001",
        entry_date: Date.current,
        status: "draft"
      )

    @account =
      @organization
        .ledger_accounts
        .find_by!(
          code: "1100"
        )
  end

  test "valid debit line" do
    line =
      build_line(
        debit: 100,
        credit: 0
      )

    assert line.valid?
    assert line.debit?
    assert_not line.credit?
    assert_equal 100.to_d, line.amount
  end

  test "valid credit line" do
    line =
      build_line(
        debit: 0,
        credit: 100
      )

    assert line.valid?
    assert line.credit?
    assert_not line.debit?
    assert_equal 100.to_d, line.amount
  end

  test "cannot contain debit and credit together" do
    line =
      build_line(
        debit: 100,
        credit: 100
      )

    assert_not line.valid?
  end

  test "cannot contain zero debit and zero credit" do
    line =
      build_line(
        debit: 0,
        credit: 0
      )

    assert_not line.valid?
  end

  test "ledger account must belong to same organization" do
    other_user =
      create_user

    other_organization =
      provision_organization_for(
        other_user
      )

    foreign_account =
      other_organization
        .ledger_accounts
        .find_by!(
          code: "1100"
        )

    line =
      build_line(
        ledger_account:
          foreign_account
      )

    assert_not line.valid?

    assert_includes(
      line.errors[:ledger_account],
      "must belong to the same organization"
    )
  end

  test "branch must belong to same organization" do
    other_user =
      create_user

    other_organization =
      provision_organization_for(
        other_user
      )

    line =
      build_line(
        branch:
          other_organization.main_branch
      )

    assert_not line.valid?

    assert_includes(
      line.errors[:branch],
      "must belong to the same organization"
    )
  end

  test "heading account cannot receive journal line" do
    heading =
      @organization
        .ledger_accounts
        .find_by!(
          code: "1000"
        )

    line =
      build_line(
        ledger_account: heading
      )

    assert_not line.valid?

    assert_includes(
      line.errors[:ledger_account],
      "must be a postable account"
    )
  end

  test "line number is unique within journal entry" do
    build_line.save!

    duplicate =
      build_line

    assert_not duplicate.valid?

    assert_includes(
      duplicate.errors[:line_number],
      "has already been taken"
    )
  end

  private

  def build_line(
    ledger_account: @account,
    branch: @organization.main_branch,
    debit: 100,
    credit: 0,
    line_number: 1
  )
    JournalLine.new(
      organization: @organization,
      journal_entry: @entry,
      ledger_account: ledger_account,
      branch: branch,
      line_number: line_number,
      debit: debit,
      credit: credit
    )
  end
end
