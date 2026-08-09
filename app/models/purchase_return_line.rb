class PurchaseReturnLine < ApplicationRecord
  ITEM_TYPES = %w[
    product
    service
  ].freeze

  belongs_to :organization
  belongs_to :purchase_return
  belongs_to :purchase_line
  belongs_to :item

  belongs_to :inventory_batch,
             optional: true

  before_validation :normalize_details

  validates :line_number,
            numericality: {
              only_integer: true,
              greater_than: 0
            },
            uniqueness: {
              scope: :purchase_return_id
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

  validates :unit_cost,
            :gross_amount,
            :discount_amount,
            :tax_percentage,
            :tax_amount,
            :line_total,
            numericality: {
              greater_than_or_equal_to: 0
            }

  validates :tax_percentage,
            numericality: {
              less_than_or_equal_to: 100
            }

  validate :relationships_share_organization
  validate :source_line_matches_original_purchase
  validate :item_matches_source_line
  validate :inventory_batch_matches_context
  validate :inventory_batch_matches_purchase_line
  validate :quantity_matches_unit
  validate :discount_does_not_exceed_gross
  validate :tax_does_not_exceed_total
  validate :line_total_does_not_exceed_gross

  scope :ordered,
        -> { order(:line_number) }

  private

  def normalize_details
    self.item_name =
      item_name.to_s.strip

    self.sku =
      sku.to_s.strip.upcase.presence

    self.barcode =
      barcode.to_s.strip.presence

    self.unit_name =
      unit_name.to_s.strip

    self.unit_symbol =
      unit_symbol.to_s.strip

    self.reason_code =
      reason_code.to_s.strip.presence

    self.notes =
      notes.to_s.strip.presence
  end

  def relationships_share_organization
    [
      purchase_return,
      purchase_line,
      item,
      inventory_batch
    ].compact.each do |record|
      next if record.organization_id ==
              organization_id

      errors.add(
        :base,
        "Purchase-return-line relationships must belong " \
        "to the same organization"
      )
    end
  end

  def source_line_matches_original_purchase
    return if purchase_return.blank?
    return if purchase_line.blank?

    return if purchase_line.purchase_id ==
              purchase_return.purchase_id

    errors.add(
      :purchase_line,
      "must belong to the original purchase"
    )
  end

  def item_matches_source_line
    return if item.blank?
    return if purchase_line.blank?
    return if item_id == purchase_line.item_id

    errors.add(
      :item,
      "must match the original purchase item"
    )
  end

  def inventory_batch_matches_context
    return if inventory_batch.blank?
    return if purchase_return.blank?
    return if item.blank?

    valid =
      inventory_batch.organization_id ==
        organization_id &&
        inventory_batch.branch_id ==
          purchase_return.branch_id &&
        inventory_batch.item_id ==
          item_id

    return if valid

    errors.add(
      :inventory_batch,
      "must match the return branch and item"
    )
  end

  def inventory_batch_matches_purchase_line
    return if inventory_batch.blank?
    return if purchase_line.blank?
    return if purchase_line.inventory_batch.blank?

    return if inventory_batch.id ==
              purchase_line.inventory_batch.id

    errors.add(
      :inventory_batch,
      "must match the batch received on the purchase line"
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
    return if discount_amount.blank?
    return if gross_amount.blank?
    return if discount_amount <= gross_amount

    errors.add(
      :discount_amount,
      "cannot exceed the gross return amount"
    )
  end

  def tax_does_not_exceed_total
    return if tax_amount.blank?
    return if line_total.blank?
    return if tax_amount <= line_total

    errors.add(
      :tax_amount,
      "cannot exceed the return line total"
    )
  end

  def line_total_does_not_exceed_gross
    return if line_total.blank?
    return if gross_amount.blank?
    return if line_total <= gross_amount

    errors.add(
      :line_total,
      "cannot exceed the gross return amount"
    )
  end
end
