class InventoryAdjustmentForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  MOVEMENT_TYPES = %w[
    opening
    adjustment_in
    adjustment_out
  ].freeze

  attribute :branch_id, :integer
  attribute :item_id, :integer
  attribute :movement_type, :string, default: "opening"
  attribute :quantity, :decimal
  attribute :occurred_at, :datetime
  attribute :reference, :string
  attribute :notes, :string

  validates :branch_id,
            :item_id,
            :occurred_at,
            presence: true

  validates :movement_type,
            inclusion: {
              in: MOVEMENT_TYPES
            }

  validates :quantity,
            numericality: {
              greater_than: 0
            }

  def signed_quantity
    return -quantity.to_d if movement_type == "adjustment_out"

    quantity.to_d
  end
end
