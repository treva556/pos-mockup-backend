class SalePayment < ApplicationRecord
  belongs_to :organization
  belongs_to :sale
  belongs_to :payment_method
  belongs_to :money_account

  belongs_to :recorded_by,
             class_name: "User",
             inverse_of: :recorded_sale_payments

  before_validation :normalize_details
  before_validation :set_payment_defaults

  validates :amount,
            numericality: {
              greater_than: 0
            }

  validates :amount_tendered,
            numericality: {
              greater_than_or_equal_to: 0
            }

  validates :change_given,
            numericality: {
              greater_than_or_equal_to: 0
            }

  validates :paid_at,
            presence: true

  validate :sale_belongs_to_organization
  validate :payment_method_belongs_to_organization
  validate :money_account_belongs_to_organization
  validate :recorded_by_is_active_member
  validate :amount_tendered_covers_payment
  validate :change_matches_tendered_amount

  scope :oldest_first,
        -> { order(:paid_at, :created_at) }

  scope :recent_first,
        lambda {
          order(
            paid_at: :desc,
            created_at: :desc
          )
        }

  private

  def normalize_details
    self.reference = reference.to_s.strip.presence
    self.notes = notes.to_s.strip.presence
  end

  def set_payment_defaults
    self.amount_tendered =
      amount if amount_tendered.blank?

    self.change_given =
      amount_tendered.to_d - amount.to_d
  end

  def sale_belongs_to_organization
    return if sale.blank? || organization.blank?
    return if sale.organization_id == organization_id

    errors.add(
      :sale,
      "must belong to the same organization"
    )
  end

  def payment_method_belongs_to_organization
    return if payment_method.blank?
    return if organization.blank?

    return if payment_method.organization_id ==
              organization_id

    errors.add(
      :payment_method,
      "must belong to the same organization"
    )
  end

  def money_account_belongs_to_organization
    return if money_account.blank? || organization.blank?

    return if money_account.organization_id ==
              organization_id

    errors.add(
      :money_account,
      "must belong to the same organization"
    )
  end

  def recorded_by_is_active_member
    return if recorded_by.blank? || organization.blank?

    return if organization
      .memberships
      .active
      .exists?(user_id: recorded_by_id)

    errors.add(
      :recorded_by,
      "must be an active organization member"
    )
  end

  def amount_tendered_covers_payment
    return if amount.blank? || amount_tendered.blank?
    return if amount_tendered >= amount

    errors.add(
      :amount_tendered,
      "must cover the applied payment amount"
    )
  end

  def change_matches_tendered_amount
    return if amount.blank?
    return if amount_tendered.blank?
    return if change_given.blank?

    expected_change =
      amount_tendered.to_d - amount.to_d

    return if change_given.to_d == expected_change

    errors.add(
      :change_given,
      "must equal the tendered amount minus the payment"
    )
  end
end
