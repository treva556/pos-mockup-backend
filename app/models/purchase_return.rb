class PurchaseReturn < ApplicationRecord
  include AuditImmutable

  STATUSES = {
    draft: "draft",
    completed: "completed",
    cancelled: "cancelled"
  }.freeze

  REASON_CODES = {
    defective: "defective",
    damaged: "damaged",
    expired: "expired",
    wrong_item: "wrong_item",
    excess_delivery: "excess_delivery",
    quality_issue: "quality_issue",
    supplier_recall: "supplier_recall",
    other: "other"
  }.freeze

  belongs_to :organization
  belongs_to :branch
  belongs_to :purchase

  belongs_to :recorded_by,
             class_name: "User",
             inverse_of: :recorded_purchase_returns

  has_many :purchase_return_lines,
           dependent: :restrict_with_error

  has_many :supplier_credits,
           dependent: :restrict_with_error

  has_many :stock_movements,
           as: :source,
           dependent: :restrict_with_error

  enum :status,
       STATUSES,
       validate: true

  enum :reason_code,
       REASON_CODES,
       prefix: :reason,
       validate: true

  before_validation :normalize_details

  validates :return_number,
            presence: true,
            uniqueness: {
              scope: :organization_id
            }

  validates :subtotal,
            :discount_total,
            :tax_total,
            :total,
            numericality: {
              greater_than_or_equal_to: 0
            }

  validate :relationships_share_organization
  validate :branch_matches_original_purchase
  validate :original_purchase_is_received
  validate :recorded_by_is_active_member
  validate :discount_does_not_exceed_subtotal
  validate :tax_does_not_exceed_total
  validate :completed_return_has_time
  validate :completed_return_has_lines
  validate :completed_totals_match_lines
  validate :quantities_do_not_exceed_original_purchase

  scope :recent_first,
        lambda {
          order(
            returned_at: :desc,
            created_at: :desc
          )
        }

  scope :for_branch,
        ->(branch) { where(branch: branch) }

  scope :for_purchase,
        ->(purchase) { where(purchase: purchase) }

  def supplier_credit_total
    supplier_credits
        .where.not(status: "cancelled")
        .sum(:amount)
        .to_d
  end

    def prior_completed_return_total
    return 0.to_d unless persisted?

    purchase
        .purchase_returns
        .completed
        .where("id < ?", id)
        .sum(:total)
        .to_d
    end

    def debt_offset_amount
    return 0.to_d unless completed?

    payable_before_this_return =
        [
        purchase.balance_due.to_d -
            prior_completed_return_total,
        0.to_d
        ].max

    [
        total.to_d,
        payable_before_this_return
    ].min
    end

    def supplier_credit_due
    return 0.to_d unless completed?

    [
        total.to_d -
        debt_offset_amount,
        0.to_d
    ].max
    end

    def uncredited_balance
    [
        supplier_credit_due -
        supplier_credit_total,
        0.to_d
    ].max
    end

  private


  def audit_record_immutable?
    status_in_database == "completed"
  end


  def normalize_details
    self.return_number =
      return_number.to_s.strip.upcase

    self.supplier_document_number =
      supplier_document_number
        .to_s
        .strip
        .upcase
        .presence

    self.reason_details =
      reason_details.to_s.strip.presence

    self.notes =
      notes.to_s.strip.presence
  end

  def relationships_share_organization
    [
      branch,
      purchase
    ].compact.each do |record|
      next if record.organization_id ==
              organization_id

      errors.add(
        :base,
        "Purchase-return relationships must belong " \
        "to the same organization"
      )
    end
  end

  def branch_matches_original_purchase
    return if branch.blank?
    return if purchase.blank?

    return if branch_id ==
              purchase.branch_id

    errors.add(
      :branch,
      "must match the original purchase branch"
    )
  end

  def original_purchase_is_received
    return if purchase.blank?
    return if purchase.received?

    errors.add(
      :purchase,
      "must be received before it can be returned"
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

  def discount_does_not_exceed_subtotal
    return if subtotal.blank?
    return if discount_total.blank?
    return if discount_total <= subtotal

    errors.add(
      :discount_total,
      "cannot exceed the return subtotal"
    )
  end

  def tax_does_not_exceed_total
    return if tax_total.blank?
    return if total.blank?
    return if tax_total <= total

    errors.add(
      :tax_total,
      "cannot exceed the return total"
    )
  end

  def completed_return_has_time
    return unless completed?
    return if returned_at.present?

    errors.add(
      :returned_at,
      "must be present for a completed return"
    )
  end

  def completed_return_has_lines
    return unless completed?
    return if purchase_return_lines.exists?

    errors.add(
      :purchase_return_lines,
      "must contain at least one returned item"
    )
  end

  def completed_totals_match_lines
    return unless completed?
    return unless purchase_return_lines.exists?

    expected = calculated_line_totals

    add_total_error(
      :subtotal,
      expected[:subtotal]
    )

    add_total_error(
      :discount_total,
      expected[:discount_total]
    )

    add_total_error(
      :tax_total,
      expected[:tax_total]
    )

    add_total_error(
      :total,
      expected[:total]
    )
  end

  def calculated_line_totals
    {
      subtotal:
        purchase_return_lines
          .sum(:gross_amount)
          .to_d,
      discount_total:
        purchase_return_lines
          .sum(:discount_amount)
          .to_d,
      tax_total:
        purchase_return_lines
          .sum(:tax_amount)
          .to_d,
      total:
        purchase_return_lines
          .sum(:line_total)
          .to_d
    }
  end

  def add_total_error(attribute, expected)
    return if public_send(attribute).to_d ==
              expected

    errors.add(
      attribute,
      "must equal the sum of the return lines"
    )
  end

  def quantities_do_not_exceed_original_purchase
    return unless completed?

    grouped_lines =
        purchase_return_lines
        .to_a
        .group_by(&:purchase_line_id)

    grouped_lines.each_value do |lines|
        source_line =
        lines.first.purchase_line

        next if source_line.blank?

        requested_quantity =
        lines.sum do |line|
            line.quantity.to_d
        end

        available_quantity =
        source_line.returnable_quantity(
            excluding_return: self
        )

        next if requested_quantity <=
                available_quantity

        errors.add(
        :purchase_return_lines,
        "#{source_line.item_name} only has " \
        "#{available_quantity.to_s('F')} " \
        "remaining returnable units"
        )
    end
    end
end
