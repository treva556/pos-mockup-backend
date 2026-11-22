class AccountingPeriod < ApplicationRecord
  STATUSES = {
    open: "open",
    closed: "closed"
  }.freeze

  belongs_to :organization

  belongs_to :closed_by,
             class_name: "User",
             optional: true


  enum :status,
       STATUSES,
       prefix: true,
       validate: true

  validates :name,
            presence: true,
            length: {
              maximum: 100
            }

  validates :starts_on,
            :ends_on,
            presence: true

  validate :ends_on_not_before_starts_on
  validate :period_does_not_overlap
  validate :closed_period_has_closure_details

  scope :chronological,
        -> {
          order(
            starts_on: :asc
          )
        }

  scope :containing_date,
        lambda { |date|
          where(
            "starts_on <= ? AND ends_on >= ?",
            date,
            date
          )
        }

  def includes_date?(date)
    return false if date.blank?
    return false if starts_on.blank?
    return false if ends_on.blank?

    date.between?(
      starts_on,
      ends_on
    )
  end

  private

  def ends_on_not_before_starts_on
    return if starts_on.blank?
    return if ends_on.blank?
    return if ends_on >= starts_on

    errors.add(
      :ends_on,
      "cannot be before the start date"
    )
  end

  def period_does_not_overlap
    return if organization.blank?
    return if starts_on.blank?
    return if ends_on.blank?

    overlapping =
      organization
        .accounting_periods
        .where.not(
          id: id
        )
        .where(
          "starts_on <= ? AND ends_on >= ?",
          ends_on,
          starts_on
        )
        .exists?

    return unless overlapping

    errors.add(
      :base,
      "Accounting period overlaps an existing period"
    )
  end

  def closed_period_has_closure_details
    if status_closed?
      errors.add(
        :closed_at,
        "must be present when period is closed"
      ) if closed_at.blank?

      errors.add(
        :closed_by,
        "must be present when period is closed"
      ) if closed_by.blank?
    else
      errors.add(
        :closed_at,
        "must be blank while period is open"
      ) if closed_at.present?

      errors.add(
        :closed_by,
        "must be blank while period is open"
      ) if closed_by.present?
    end
  end
end
