require "test_helper"

class LedgerAccountTest < ActiveSupport::TestCase
  def setup
    @organization =
      Organization.create!(
        name: "Accounting Test Company",
        country_code: "KE",
        currency_code: "KES",
        time_zone: "Africa/Nairobi"
      )
  end

  test "valid ledger account" do
    account =
      build_account

    assert account.valid?
  end

  test "normalizes account code and name" do
    account =
      build_account(
        code: "  1100  ",
        name: "  Accounts Receivable  "
      )

    account.validate

    assert_equal "1100", account.code
    assert_equal(
      "Accounts Receivable",
      account.name
    )
  end

  test "account code is unique within organization" do
    build_account.save!

    duplicate =
      build_account

    assert_not duplicate.valid?

    assert_includes(
      duplicate.errors[:code],
      "has already been taken"
    )
  end

  test "same code may exist in another organization" do
    build_account.save!

    other_organization =
      Organization.create!(
        name: "Other Company",
        country_code: "KE",
        currency_code: "KES",
        time_zone: "Africa/Nairobi"
      )

    account =
      build_account(
        organization: other_organization
      )

    assert account.valid?
  end

  test "parent must belong to same organization" do
    other_organization =
      Organization.create!(
        name: "Other Company",
        country_code: "KE",
        currency_code: "KES",
        time_zone: "Africa/Nairobi"
      )

    foreign_parent =
      build_account(
        organization: other_organization,
        code: "1000",
        name: "Assets",
        postable: false
      )

    foreign_parent.save!

    account =
      build_account(
        parent: foreign_parent
      )

    assert_not account.valid?

    assert_includes(
      account.errors[:parent],
      "must belong to the same organization"
    )
  end

  test "account hierarchy cannot contain a cycle" do
    parent =
      build_account(
        code: "1000",
        name: "Assets",
        postable: false
      )

    parent.save!

    child =
      build_account(
        code: "1100",
        name: "Current Assets",
        parent: parent,
        postable: false
      )

    child.save!

    parent.parent =
      child

    assert_not parent.valid?

    assert_includes(
      parent.errors[:parent],
      "cannot be a descendant of this account"
    )
  end

  private

  def build_account(
    organization: @organization,
    code: "1100",
    name: "Accounts Receivable",
    parent: nil,
    account_type: "asset",
    normal_balance: "debit",
    report_group: "current_asset",
    postable: true
  )
    LedgerAccount.new(
      organization: organization,
      code: code,
      name: name,
      parent: parent,
      account_type: account_type,
      normal_balance: normal_balance,
      report_group: report_group,
      postable: postable,
      active: true,
      system_account: false
    )
  end
end
