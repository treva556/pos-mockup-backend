require "test_helper"

class AccountingPeriodTest < ActiveSupport::TestCase
  setup do
    @owner =
      create_user

    @organization =
      provision_organization_for(
        @owner
      )
  end

  test "valid open accounting period" do
    period =
      @organization
        .accounting_periods
        .new(
          name: "November 2026",
          starts_on: Date.new(2026, 11, 1),
          ends_on: Date.new(2026, 11, 30),
          status: "open"
        )

    assert period.valid?
  end

  test "rejects ending before start date" do
    period =
      @organization
        .accounting_periods
        .new(
          name: "Invalid period",
          starts_on: Date.new(2026, 11, 30),
          ends_on: Date.new(2026, 11, 1)
        )

    assert_not period.valid?

    assert_includes(
      period.errors[:ends_on],
      "cannot be before the start date"
    )
  end

  test "rejects overlapping accounting periods" do
    @organization
      .accounting_periods
      .create!(
        name: "November 2026",
        starts_on: Date.new(2026, 11, 1),
        ends_on: Date.new(2026, 11, 30)
      )

    overlapping =
      @organization
        .accounting_periods
        .new(
          name: "Overlap",
          starts_on: Date.new(2026, 11, 15),
          ends_on: Date.new(2026, 12, 15)
        )

    assert_not overlapping.valid?

    assert_includes(
      overlapping.errors[:base],
      "Accounting period overlaps an existing period"
    )
  end

  test "closed period requires closure details" do
    period =
      @organization
        .accounting_periods
        .new(
          name: "November 2026",
          starts_on: Date.new(2026, 11, 1),
          ends_on: Date.new(2026, 11, 30),
          status: "closed"
        )

    assert_not period.valid?

    assert_includes(
      period.errors[:closed_at],
      "must be present when period is closed"
    )

    assert_includes(
      period.errors[:closed_by],
      "must be present when period is closed"
    )
  end
end
