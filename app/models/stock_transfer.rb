class StockTransfer < ApplicationRecord
  belongs_to :organization

  belongs_to :from_branch,
             class_name: "Branch",
             inverse_of: :outgoing_stock_transfers

  belongs_to :to_branch,
             class_name: "Branch",
             inverse_of: :incoming_stock_transfers

  belongs_to :item

  belongs_to :recorded_by,
             class_name: "User",
             inverse_of: :recorded_stock_transfers

  has_many :stock_movements,
           as: :source,
           dependent: :restrict_with_error

  before_validation :normalize_details

  validates :quantity,
            numericality: {
              greater_than: 0
            }

  validates :transferred_at,
            presence: true

  validate :branches_are_different
  validate :from_branch_belongs_to_organization
  validate :to_branch_belongs_to_organization
  validate :branches_are_active
  validate :item_belongs_to_organization
  validate :item_is_stockable
  validate :recorded_by_belongs_to_organization
  validate :quantity_matches_unit

  scope :recent_first,
        lambda {
          order(
            transferred_at: :desc,
            created_at: :desc
          )
        }

  private

  def normalize_details
    self.reference = reference.to_s.strip.presence
    self.notes = notes.to_s.strip.presence
  end

  def branches_are_different
    return if from_branch.blank? || to_branch.blank?
    return unless from_branch_id == to_branch_id

    errors.add(
      :to_branch,
      "must be different from the source branch"
    )
  end

  def from_branch_belongs_to_organization
    return if from_branch.blank? || organization.blank?
    return if from_branch.organization_id == organization_id

    errors.add(
      :from_branch,
      "must belong to the same organization"
    )
  end

  def to_branch_belongs_to_organization
    return if to_branch.blank? || organization.blank?
    return if to_branch.organization_id == organization_id

    errors.add(
      :to_branch,
      "must belong to the same organization"
    )
  end

  def branches_are_active
    if from_branch.present? && !from_branch.active?
      errors.add(:from_branch, "must be active")
    end

    if to_branch.present? && !to_branch.active?
      errors.add(:to_branch, "must be active")
    end
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
end
