class SupplierCredit < ApplicationRecord
  STATUSES = {
    pending: "pending",
    available: "available",
    partially_applied: "partially_applied",
    applied: "applied",
    cancelled: "cancelled"
  }.freeze

  belongs_to :organization
  belongs_to :purchase_return

  belongs_to :recorded_by,
             class_name: "User",
             inverse_of: :recorded_supplier_credits

  enum :status,
       STATUSES,
       validate: true

  before_validation :normalize_details

  validates :amount,
            numericality: {
              greater_than: 0
            }

  validates :applied_amount,
            numericality: {
              greater_than_or_equal_to: 0
            }

  validates :credit_number,
            uniqueness: {
              scope: :organization_id,
              case_sensitive: false
            },
            allow_blank: true

  validate :relationships_share_organization
  validate :purchase_return_is_completed
  validate :recorded_by_is_active_member
  validate :applied_amount_does_not_exceed_amount
  validate :issued_credit_has_document_details
  validate :status_matches_applied_amount

  scope :recent_first,
        -> { order(issued_on: :desc, created_at: :desc) }

  scope :usable,
        lambda {
          where(
            status: %w[
              available
              partially_applied
            ]
          )
        }

  def available_amount
    [
      amount.to_d - applied_amount.to_d,
      0.to_d
    ].max
  end

  private

  def normalize_details
    self.credit_number =
      credit_number.to_s.strip.upcase.presence

    self.notes =
      notes.to_s.strip.presence
  end

  def relationships_share_organization
    return if purchase_return.blank?
    return if purchase_return.organization_id ==
              organization_id

    errors.add(
      :purchase_return,
      "must belong to the same organization"
    )
  end

  def purchase_return_is_completed
    return if purchase_return.blank?
    return if purchase_return.completed?

    errors.add(
      :purchase_return,
      "must be completed before supplier credit is recorded"
    )
  end

  def recorded_by_is_active_member
    return if recorded_by.blank?
    return if organization.blank?

    return if organization
      .memberships
      .active
      .exists?(user_id: recorded_by_id)

    errors.add(
      :recorded_by,
      "must be an active organization member"
    )
  end

  def applied_amount_does_not_exceed_amount
    return if amount.blank?
    return if applied_amount.blank?
    return if applied_amount <= amount

    errors.add(
      :applied_amount,
      "cannot exceed the supplier credit amount"
    )
  end

  def issued_credit_has_document_details
    return if pending? || cancelled?

    if issued_on.blank?
      errors.add(
        :issued_on,
        "must be present for an issued supplier credit"
      )
    end

    return if credit_number.present?

    errors.add(
      :credit_number,
      "must be present for an issued supplier credit"
    )
  end

  def status_matches_applied_amount
    return if amount.blank?
    return if applied_amount.blank?

    case status
    when "pending", "available"
      return if applied_amount.zero?
    when "partially_applied"
      return if applied_amount.positive? &&
                applied_amount < amount
    when "applied"
      return if applied_amount == amount
    when "cancelled"
      return
    end

    errors.add(
      :status,
      "does not match the applied supplier credit amount"
    )
  end
end
