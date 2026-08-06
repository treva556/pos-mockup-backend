class Purchase < ApplicationRecord
  belongs_to :organization
  belongs_to :branch
  belongs_to :supplier

  belongs_to :recorded_by,
             class_name: "User"

  has_many :purchase_lines,
           -> { order(:line_number) },
           dependent: :restrict_with_error

  has_many :purchase_payments,
           dependent: :restrict_with_error

  has_many :stock_movements,
           as: :source,
           dependent: :restrict_with_error

  enum :status,
       {
         draft: "draft",
         received: "received",
         cancelled: "cancelled"
       },
       validate: true

  enum :payment_status,
       {
         unpaid: "unpaid",
         partially_paid: "partially_paid",
         paid: "paid"
       },
       prefix: :payment,
       validate: true

  validates :purchase_number,
            presence: true,
            uniqueness: {
              scope: :organization_id
            }

  validates :purchased_on,
            :received_at,
            presence: true

  validates :subtotal,
            :discount_total,
            :tax_total,
            :total,
            :amount_paid,
            :balance_due,
            numericality: {
              greater_than_or_equal_to: 0
            }

  validate :relationships_share_organization
  validate :amounts_are_consistent
  validate :due_date_is_valid

  scope :recent_first,
        -> {
          order(
            purchased_on: :desc,
            created_at: :desc
          )
        }

  scope :with_outstanding_balance,
        -> { where("balance_due > 0") }

  def outstanding?
    balance_due.to_d.positive?
  end

  def overdue?(on = Date.current)
    outstanding? &&
        due_on.present? &&
        due_on < on
  end

  private

  def relationships_share_organization
    [
      branch,
      supplier
    ].compact.each do |record|
      next if record.organization_id ==
              organization_id

      errors.add(
        :base,
        "Purchase relationships must belong to " \
        "the same organization"
      )
    end
  end

  def amounts_are_consistent
    return if total.blank?
    return if amount_paid.blank?
    return if balance_due.blank?

    expected_balance =
      total.to_d - amount_paid.to_d

    return if balance_due.to_d ==
              expected_balance

    errors.add(
      :balance_due,
      "must equal total minus amount paid"
    )
  end

  def due_date_is_valid
    return if due_on.blank?
    return if purchased_on.blank?
    return if due_on >= purchased_on

    errors.add(
      :due_on,
      "cannot be before the purchase date"
    )
  end
end
