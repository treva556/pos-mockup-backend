class InventoryBatch < ApplicationRecord
  belongs_to :organization
  belongs_to :branch
  belongs_to :item

  belongs_to :purchase_line,
             optional: true

  has_many :stock_movements,
           dependent: :restrict_with_error

  enum :status,
       {
         active: "active",
         quarantined: "quarantined",
         depleted: "depleted"
       },
       validate: true

  validates :expires_on,
            :received_at,
            presence: true

  validates :quantity_received,
            numericality: {
              greater_than: 0
            }

  validates :quantity_remaining,
            numericality: {
              greater_than_or_equal_to: 0
            }

  validates :unit_cost,
            numericality: {
              greater_than_or_equal_to: 0
            }

  validates :batch_number,
            uniqueness: {
              scope: %i[
                organization_id
                branch_id
                item_id
              ]
            },
            allow_blank: true

  validate :relationships_share_context
  validate :item_uses_expiry_tracking
  validate :remaining_not_above_received
  validate :manufacture_date_is_valid

  before_validation :normalize_batch_number
  before_validation :mark_depleted_when_empty

  scope :with_quantity,
        -> { where("quantity_remaining > 0") }

  scope :unexpired,
        lambda { |on = Date.current|
          where("expires_on >= ?", on)
        }

  scope :expired,
        lambda { |on = Date.current|
          where("expires_on < ?", on)
        }

  scope :sellable,
        lambda { |on = Date.current|
          active
            .with_quantity
            .unexpired(on)
        }

  scope :fefo,
        lambda {
          order(
            expires_on: :asc,
            received_at: :asc,
            id: :asc
          )
        }

  def expired?(on = Date.current)
    expires_on < on
  end

  def sellable?(on = Date.current)
    active? &&
      quantity_remaining.positive? &&
      !expired?(on)
  end

  def days_until_expiry(on = Date.current)
    (expires_on - on).to_i
  end

  def remaining_value
    quantity_remaining.to_d *
      unit_cost.to_d
  end

  private

  def normalize_batch_number
    self.batch_number =
      batch_number.to_s.strip.presence
  end

  def mark_depleted_when_empty
    return if quantity_remaining.blank?
    return unless quantity_remaining.zero?

    self.status = "depleted"
  end

  def relationships_share_context
    if branch.present? &&
       branch.organization_id != organization_id
      errors.add(
        :branch,
        "must belong to the same organization"
      )
    end

    if item.present? &&
       item.organization_id != organization_id
      errors.add(
        :item,
        "must belong to the same organization"
      )
    end

    return if purchase_line.blank?

    if purchase_line.organization_id !=
       organization_id
      errors.add(
        :purchase_line,
        "must belong to the same organization"
      )
    end

    return if purchase_line.item_id == item_id

    errors.add(
      :purchase_line,
      "must contain the same item"
    )
  end

  def item_uses_expiry_tracking
    return if item.blank?
    return if item.tracks_expiry?

    errors.add(
      :item,
      "must have expiry tracking enabled"
    )
  end

  def remaining_not_above_received
    return if quantity_received.blank?
    return if quantity_remaining.blank?

    return if quantity_remaining <=
              quantity_received

    errors.add(
      :quantity_remaining,
      "cannot exceed quantity received"
    )
  end

  def manufacture_date_is_valid
    return if manufactured_on.blank?
    return if expires_on.blank?
    return if manufactured_on <= expires_on

    errors.add(
      :manufactured_on,
      "cannot be after the expiry date"
    )
  end
end
