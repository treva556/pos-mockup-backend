require "test_helper"

class Accounting::AccountingPeriodsControllerTest <
  ActionDispatch::IntegrationTest
  setup do
    @owner =
      create_user

    @organization =
      provision_organization_for(
        @owner
      )

    @organization.update!(
      accounting_enabled: true
    )

    sign_in_as(
      @owner
    )
  end

  test "index displays accounting periods" do
    @organization
      .accounting_periods
      .create!(
        name: "November 2026",
        starts_on: Date.new(2026, 11, 1),
        ends_on: Date.new(2026, 11, 30)
      )

    get accounting_accounting_periods_path

    assert_response :success

    assert_select(
      "body",
      text:
        /November 2026/
    )
  end

  test "new displays accounting period form" do
    get new_accounting_accounting_period_path

    assert_response :success

    assert_select(
      "h1",
      text:
        "New Accounting Period"
    )
  end

  test "creates open accounting period" do
    assert_difference(
      -> {
        @organization
          .accounting_periods
          .count
      },
      1
    ) do
      post accounting_accounting_periods_path,
           params: {
             accounting_period: {
               name:
                 "December 2026",
               starts_on:
                 "2026-12-01",
               ends_on:
                 "2026-12-31"
             }
           }
    end

    period =
      @organization
        .accounting_periods
        .order(:id)
        .last

    assert period.status_open?

    assert_redirected_to(
      accounting_accounting_periods_path
    )
  end

  test "rejects overlapping accounting period" do
    @organization
      .accounting_periods
      .create!(
        name: "November 2026",
        starts_on: Date.new(2026, 11, 1),
        ends_on: Date.new(2026, 11, 30)
      )

    assert_no_difference(
      -> {
        @organization
          .accounting_periods
          .count
      }
    ) do
      post accounting_accounting_periods_path,
           params: {
             accounting_period: {
               name:
                 "Overlap",
               starts_on:
                 "2026-11-15",
               ends_on:
                 "2026-12-15"
             }
           }
    end

    assert_response :unprocessable_entity

    assert_select(
      "body",
      text:
        /overlaps an existing period/i
    )
  end

  test "closes open accounting period" do
    period =
      @organization
        .accounting_periods
        .create!(
          name: "November 2026",
          starts_on: Date.new(2026, 11, 1),
          ends_on: Date.new(2026, 11, 30)
        )

    post close_accounting_accounting_period_path(
      period
    )

    period.reload

    assert period.status_closed?
    assert_equal @owner,
                 period.closed_by
    assert_not_nil period.closed_at

    assert_redirected_to(
      accounting_accounting_periods_path
    )
  end

  test "cannot close another organizations accounting period" do
    other_owner =
      create_user

    other_organization =
      provision_organization_for(
        other_owner
      )

    foreign_period =
      other_organization
        .accounting_periods
        .create!(
          name: "Foreign period",
          starts_on: Date.new(2026, 11, 1),
          ends_on: Date.new(2026, 11, 30)
        )

    post close_accounting_accounting_period_path(
      foreign_period
    )

    assert_response :not_found

    assert foreign_period.reload.status_open?
  end
end
