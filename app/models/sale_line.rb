class SaleLine < ApplicationRecord
  ITEM_TYPES = %w[
    product
    service
  ].freeze

  belongs_to :organization
  belongs_to :sale
  belongs_to :item
  belongs_to :tax_rate, optional: true

  validates :line_number,
            numericality: {
              only_integer: true,
              greater_than: 0
            },
            uniqueness: {
              scope: :sale_id
            }

  validates :item_name,
            :item_type,
            :unit_name,
            :unit_symbol,
            presence: true

  validates :item_type,
            inclusion: {
              in: ITEM_TYPES
            }

  validates :quantity,
            numericality: {
              greater_than: 0
            }

  validates :unit_price,
            :unit_cost,
            :gross_amount,
            :discount_amount,
            :tax_rate_percentage,
            :tax_amount,
            :line_total,
            numericality: {
              greater_than_or_equal_to: 0
            }

  validates :tax_rate_percentage,
            numericality: {
              less_than_or_equal_to: 100
            }

  validate :sale_belongs_to_organization
  validate :item_belongs_to_organization
  validate :tax_rate_belongs_to_organization
  validate :quantity_matches_unit
  validate :discount_does_not_exceed_gross
  validate :tax_does_not_exceed_line_total
  validate :line_total_does_not_exceed_gross

  scope :ordered,
        -> { order(:line_number) }

  private

  def sale_belongs_to_organization
    return if sale.blank? || organization.blank?
    return if sale.organization_id == organization_id

    errors.add(
      :sale,
      "must belong to the same organization"
    )
  end

  def item_belongs_to_organization
    return if item.blank? || organization.blank?
    return if item.organization_id == organization_id

    errors.add(
      :item,
      "must belong to the same organization"
    )
  end

  def tax_rate_belongs_to_organization
    return if tax_rate.blank? || organization.blank?
    return if tax_rate.organization_id == organization_id

    errors.add(
      :tax_rate,
      "must belong to the same organization"
    )
  end

  def quantity_matches_unit
    return if item.blank?
    return if item.unit_of_measure.blank?
    return if item.unit_of_measure.decimal_allowed?
    return if quantity.blank?
    return if (quantity.to_d % 1).zero?

    errors.add(
      :quantity,
      "must be a whole number for this unit"
    )
  end

  def discount_does_not_exceed_gross
    return if gross_amount.blank?
    return if discount_amount.blank?
    return if discount_amount <= gross_amount

    errors.add(
      :discount_amount,
      "cannot exceed the gross amount"
    )
  end

  def tax_does_not_exceed_line_total
    return if tax_amount.blank? || line_total.blank?
    return if tax_amount <= line_total

    errors.add(
      :tax_amount,
      "cannot exceed the line total"
    )
  end

  def line_total_does_not_exceed_gross
    return if line_total.blank? || gross_amount.blank?
    return if line_total <= gross_amount

    errors.add(
      :line_total,
      "cannot exceed the gross amount"
    )
  end
end
