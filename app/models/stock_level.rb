class StockLevel < ApplicationRecord
  belongs_to :organization
  belongs_to :branch
  belongs_to :item

  validates :quantity_on_hand,
            numericality: {
              greater_than_or_equal_to: 0
            }

  validates :reorder_level,
            numericality: {
              greater_than_or_equal_to: 0
            }


  validate :branch_belongs_to_organization
  validate :item_belongs_to_organization
  validate :item_is_stockable
  validate :quantities_match_unit

  scope :for_branch,
        ->(branch) { where(branch: branch) }

  scope :low_stock,
      lambda {
        where(
          "reorder_level > 0 AND " \
          "quantity_on_hand > 0 AND " \
          "quantity_on_hand <= reorder_level"
        )
      }

  scope :out_of_stock,
        -> { where(quantity_on_hand: 0) }

  def low_stock?
    reorder_level.positive? &&
        quantity_on_hand.positive? &&
        quantity_on_hand <= reorder_level
  end

  def out_of_stock?
    quantity_on_hand.zero?
  end

  private

  def branch_belongs_to_organization
    return if branch.blank? || organization.blank?
    return if branch.organization_id == organization_id

    errors.add(
      :branch,
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

  def item_is_stockable
    return if item.blank?
    return if item.stockable?

    errors.add(
      :item,
      "must be an inventory-tracked product"
    )
  end

  def quantities_match_unit
    return if item.blank?
    return if item.unit_of_measure.blank?
    return if item.unit_of_measure.decimal_allowed?

    validate_whole_quantity(:quantity_on_hand)
    validate_whole_quantity(:reorder_level)
  end

  def validate_whole_quantity(attribute)
    value = public_send(attribute)
    return if value.blank?
    return if (value.to_d % 1).zero?

    errors.add(
      attribute,
      "must be a whole number for this unit"
    )
  end
end
