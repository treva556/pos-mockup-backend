class CustomerRefund < ApplicationRecord
  belongs_to :organization
  belongs_to :sale_return
  belongs_to :payment_method
  belongs_to :money_account

  belongs_to :recorded_by,
             class_name: "User",
             inverse_of: :recorded_customer_refunds

  before_validation :normalize_details

  validates :amount,
            numericality: {
              greater_than: 0
            }

  validates :refunded_at,
            presence: true

  validate :relationships_share_organization
  validate :sale_return_is_completed
  validate :recorded_by_is_active_member
  validate :money_account_matches_return_branch
  validate :money_account_can_pay

  scope :recent_first,
        lambda {
          order(
            refunded_at: :desc,
            created_at: :desc
          )
        }

  private

  def normalize_details
    self.reference =
      reference.to_s.strip.presence

    self.notes =
      notes.to_s.strip.presence
  end

  def relationships_share_organization
    [
      sale_return,
      payment_method,
      money_account
    ].compact.each do |record|
      next if record.organization_id ==
              organization_id

      errors.add(
        :base,
        "Refund relationships must belong to " \
        "the same organization"
      )
    end
  end

  def sale_return_is_completed
    return if sale_return.blank?
    return if sale_return.completed?

    errors.add(
      :sale_return,
      "must be completed before a refund is recorded"
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

  def money_account_matches_return_branch
    return if money_account.blank?
    return if sale_return.blank?
    return if money_account.branch_id.blank?

    return if money_account.branch_id ==
              sale_return.branch_id

    errors.add(
      :money_account,
      "must belong to the return branch"
    )
  end

  def money_account_can_pay
    return if money_account.blank?
    return if money_account.can_pay?

    errors.add(
      :money_account,
      "must allow outgoing payments"
    )
  end
end
