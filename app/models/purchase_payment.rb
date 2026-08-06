class PurchasePayment < ApplicationRecord
  belongs_to :organization
  belongs_to :purchase
  belongs_to :payment_method
  belongs_to :money_account

  belongs_to :recorded_by,
             class_name: "User"

  validates :amount,
            numericality: {
              greater_than: 0
            }

  validates :paid_at,
            presence: true

  validate :relationships_share_organization
  validate :purchase_is_received

  scope :oldest_first,
        -> { order(:paid_at, :created_at) }

  scope :recent_first,
        -> { order(paid_at: :desc, created_at: :desc) }

  private

  def relationships_share_organization
    [
      purchase,
      payment_method,
      money_account
    ].compact.each do |record|
      next if record.organization_id ==
              organization_id

      errors.add(
        :base,
        "Purchase-payment relationships must belong " \
        "to the same organization"
      )
    end
  end

  def purchase_is_received
    return if purchase.blank?
    return if purchase.received?

    errors.add(
      :purchase,
      "must be a received purchase"
    )
  end
end
