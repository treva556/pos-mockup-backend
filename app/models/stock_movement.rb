class StockMovement < ApplicationRecord
  INBOUND_TYPES = %w[
    opening
    adjustment_in
    purchase
    sale_return
    transfer_in
  ].freeze

  OUTBOUND_TYPES = %w[
    adjustment_out
    sale
    purchase_return
    transfer_out
  ].freeze

  belongs_to :organization
  belongs_to :branch
  belongs_to :item

  belongs_to :recorded_by,
             class_name: "User",
             inverse_of: :recorded_stock_movements

  belongs_to :source,
             polymorphic: true,
             optional: true

  belongs_to :inventory_batch,
           optional: true

  enum :movement_type, {
    opening: "opening",
    adjustment_in: "adjustment_in",
    adjustment_out: "adjustment_out",
    purchase: "purchase",
    sale: "sale",
    sale_return: "sale_return",
    purchase_return: "purchase_return",
    transfer_in: "transfer_in",
    transfer_out: "transfer_out",
    purchase: "purchase"
  }, validate: true

  before_validation :normalize_details

  validates :quantity_change,
            numericality: {
              other_than: 0
            }

  validates :occurred_at,
            presence: true

  validate :branch_belongs_to_organization
  validate :item_belongs_to_organization
  validate :item_is_stockable
  validate :recorded_by_belongs_to_organization
  validate :movement_direction_matches_type
  validate :quantity_matches_unit
  validate :inventory_batch_matches_movement

  scope :recent_first,
        lambda {
          order(
            occurred_at: :desc,
            created_at: :desc
          )
        }

  scope :for_branch,
        ->(branch) { where(branch: branch) }

  scope :for_item,
        ->(item) { where(item: item) }

  def inbound?
    quantity_change.to_d.positive?
  end

  def outbound?
    quantity_change.to_d.negative?
  end

  def quantity
    quantity_change.to_d.abs
  end

  private

  def normalize_details
    self.reference =
      reference.to_s.strip.presence

    self.notes =
      notes.to_s.strip.presence
  end

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

  def recorded_by_belongs_to_organization
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

  def movement_direction_matches_type
    return if movement_type.blank?
    return if quantity_change.blank?

    change = quantity_change.to_d

    if INBOUND_TYPES.include?(movement_type)
      return if change.positive?
    elsif OUTBOUND_TYPES.include?(movement_type)
      return if change.negative?
    else
      return
    end

    errors.add(
      :quantity_change,
      "has the wrong direction for this movement type"
    )
  end

  def quantity_matches_unit
    return if item.blank?
    return if item.unit_of_measure.blank?
    return if item.unit_of_measure.decimal_allowed?
    return if quantity_change.blank?
    return if (quantity_change.to_d.abs % 1).zero?

    errors.add(
      :quantity_change,
      "must be a whole number for this unit"
    )
  end

  def inventory_batch_matches_movement
    return if inventory_batch.blank?

    valid =
      inventory_batch.organization_id ==
        organization_id &&
      inventory_batch.branch_id ==
        branch_id &&
      inventory_batch.item_id ==
        item_id

    return if valid

    errors.add(
      :inventory_batch,
      "must match the movement organization, branch and item"
    )
  end
end
