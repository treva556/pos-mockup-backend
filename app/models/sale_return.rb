class SaleReturn < ApplicationRecord
  STATUSES = {
    draft: "draft",
    completed: "completed",
    cancelled: "cancelled"
  }.freeze

  REASON_CODES = {
    defective: "defective",
    wrong_item: "wrong_item",
    damaged: "damaged",
    expired: "expired",
    customer_changed_mind: "customer_changed_mind",
    pricing_error: "pricing_error",
    duplicate_sale: "duplicate_sale",
    other: "other"
  }.freeze

  belongs_to :organization
  belongs_to :branch
  belongs_to :sale

  belongs_to :recorded_by,
             class_name: "User",
             inverse_of: :recorded_sale_returns

  has_many :sale_return_lines,
           dependent: :restrict_with_error

  has_many :customer_refunds,
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
  validate :branch_matches_original_sale
  validate :original_sale_is_completed
  validate :recorded_by_is_active_member
  validate :discount_does_not_exceed_subtotal
  validate :tax_does_not_exceed_total
  validate :completed_return_has_time
  validate :completed_return_has_lines
  validate :completed_totals_match_lines
  validate :quantities_do_not_exceed_original_sale

  scope :recent_first,
        lambda {
          order(
            returned_at: :desc,
            created_at: :desc
          )
        }

  scope :for_branch,
        ->(branch) { where(branch: branch) }

  scope :for_sale,
        ->(sale) { where(sale: sale) }

  def refund_total
    customer_refunds.sum(:amount).to_d
  end

  def refundable_balance
    [
      total.to_d - refund_total,
      0.to_d
    ].max
  end

  def refunded?
    refundable_balance.zero? &&
      total.to_d.positive?
  end

  private

  def normalize_details
    self.return_number =
      return_number.to_s.strip.upcase

    self.reason_details =
      reason_details.to_s.strip.presence

    self.notes =
      notes.to_s.strip.presence
  end

  def relationships_share_organization
    [
      branch,
      sale
    ].compact.each do |record|
      next if record.organization_id ==
              organization_id

      errors.add(
        :base,
        "Sale-return relationships must belong " \
        "to the same organization"
      )
    end
  end

  def branch_matches_original_sale
    return if branch.blank? || sale.blank?
    return if branch_id == sale.branch_id

    errors.add(
      :branch,
      "must match the original sale branch"
    )
  end

  def original_sale_is_completed
    return if sale.blank?
    return if sale.completed?

    errors.add(
      :sale,
      "must be completed before it can be returned"
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
    return if sale_return_lines.exists?

    errors.add(
      :sale_return_lines,
      "must contain at least one returned item"
    )
  end

  def completed_totals_match_lines
    return unless completed?
    return unless sale_return_lines.exists?

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
        sale_return_lines.sum(:gross_amount).to_d,
      discount_total:
        sale_return_lines.sum(:discount_amount).to_d,
      tax_total:
        sale_return_lines.sum(:tax_amount).to_d,
      total:
        sale_return_lines.sum(:line_total).to_d
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

  def quantities_do_not_exceed_original_sale
    return unless completed?

    grouped_lines =
        sale_return_lines
        .to_a
        .group_by(&:sale_line_id)

    grouped_lines.each_value do |lines|
        source_line =
        lines.first.sale_line

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
        :sale_return_lines,
        "#{source_line.item_name} only has " \
        "#{available_quantity.to_s('F')} " \
        "remaining returnable units"
        )
    end
  end
end
