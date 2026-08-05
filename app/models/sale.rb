class Sale < ApplicationRecord
  STATUSES = {
    draft: "draft",
    completed: "completed",
    cancelled: "cancelled"
  }.freeze

  PAYMENT_STATUSES = {
    unpaid: "unpaid",
    partially_paid: "partially_paid",
    paid: "paid"
  }.freeze

  belongs_to :organization
  belongs_to :branch
  belongs_to :customer, optional: true

  belongs_to :cashier,
             class_name: "User",
             inverse_of: :cashier_sales

  has_many :sale_lines,
           dependent: :restrict_with_error

  has_many :sale_payments,
           dependent: :restrict_with_error

  has_many :stock_movements,
         as: :source,
         dependent: :restrict_with_error

  enum :status,
       STATUSES,
       validate: true

  enum :payment_status,
       PAYMENT_STATUSES,
       validate: true,
       prefix: :payment

  before_validation :normalize_details

  validates :sale_number,
            presence: true,
            uniqueness: {
              scope: :organization_id
            }

  validates :subtotal,
            :discount_total,
            :tax_total,
            :total,
            :amount_paid,
            :balance_due,
            :change_given,
            numericality: {
              greater_than_or_equal_to: 0
            }

  validate :branch_belongs_to_organization
  validate :branch_is_active
  validate :customer_belongs_to_organization
  validate :cashier_is_active_member
  validate :discount_does_not_exceed_subtotal
  validate :tax_does_not_exceed_total
  validate :payment_does_not_exceed_total
  validate :payment_and_balance_match_total
  validate :completed_sale_has_sold_at
  validate :completed_credit_sale_has_customer
  validate :completed_credit_sale_has_due_date
  validate :due_date_is_not_before_sale

  scope :recent_first,
        lambda {
          order(
            sold_at: :desc,
            created_at: :desc
          )
        }

  scope :for_branch,
        ->(branch) { where(branch: branch) }

  scope :outstanding,
        -> { where.not(payment_status: "paid") }

  scope :with_outstanding_balance,
      -> { where("balance_due > 0") }

  scope :overdue,
        lambda {
            completed
            .with_outstanding_balance
            .where("due_on < ?", Date.current)
        }

  def walk_in?
    customer_id.blank?
  end

  def outstanding?
    balance_due.positive?
  end

  def editable?
    draft?
  end

  def overdue?
    completed? &&
        outstanding? &&
        due_on.present? &&
        due_on < Date.current
  end

  private

  def normalize_details
    self.sale_number = sale_number.to_s.strip.upcase
    self.notes = notes.to_s.strip.presence
  end

  def branch_belongs_to_organization
    return if branch.blank? || organization.blank?
    return if branch.organization_id == organization_id

    errors.add(
      :branch,
      "must belong to the same organization"
    )
  end

  def branch_is_active
    return if branch.blank? || branch.active?

    errors.add(:branch, "must be active")
  end

  def customer_belongs_to_organization
    return if customer.blank? || organization.blank?
    return if customer.organization_id == organization_id

    errors.add(
      :customer,
      "must belong to the same organization"
    )
  end

  def cashier_is_active_member
    return if cashier.blank? || organization.blank?

    return if organization
      .memberships
      .active
      .exists?(user_id: cashier_id)

    errors.add(
      :cashier,
      "must be an active organization member"
    )
  end

  def discount_does_not_exceed_subtotal
    return if subtotal.blank? || discount_total.blank?
    return if discount_total <= subtotal

    errors.add(
      :discount_total,
      "cannot exceed the subtotal"
    )
  end

  def tax_does_not_exceed_total
    return if tax_total.blank? || total.blank?
    return if tax_total <= total

    errors.add(
      :tax_total,
      "cannot exceed the sale total"
    )
  end

  def payment_does_not_exceed_total
    return if amount_paid.blank? || total.blank?
    return if amount_paid <= total

    errors.add(
      :amount_paid,
      "cannot exceed the sale total"
    )
  end

  def payment_and_balance_match_total
    return if total.blank?
    return if amount_paid.blank?
    return if balance_due.blank?

    expected_balance =
      total.to_d - amount_paid.to_d

    return if balance_due.to_d == expected_balance

    errors.add(
      :balance_due,
      "must equal the total minus the amount paid"
    )
  end

  def completed_sale_has_sold_at
    return unless completed?
    return if sold_at.present?

    errors.add(
      :sold_at,
      "must be present for a completed sale"
    )
  end

  def completed_credit_sale_has_customer
    return unless completed?
    return unless balance_due.to_d.positive?
    return if customer.present?

    errors.add(
        :customer,
        "must be selected for a credit sale"
    )
    end

    def completed_credit_sale_has_due_date
    return unless completed?
    return unless balance_due.to_d.positive?
    return if due_on.present?

    errors.add(
        :due_on,
        "must be provided for a credit sale"
    )
    end

    def due_date_is_not_before_sale
    return if due_on.blank?
    return if sold_at.blank?
    return if due_on >= sold_at.to_date

    errors.add(
        :due_on,
        "cannot be before the sale date"
    )
  end
end
