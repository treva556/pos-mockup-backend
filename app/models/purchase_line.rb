class PurchaseLine < ApplicationRecord
  belongs_to :organization
  belongs_to :purchase
  belongs_to :item
  belongs_to :tax_rate,
             optional: true

  has_one :inventory_batch,
        dependent: :restrict_with_error

  has_many :purchase_return_lines,
         dependent: :restrict_with_error

  validates :line_number,
            numericality: {
              only_integer: true,
              greater_than: 0
            }

  validates :item_name,
            :item_type,
            :unit_name,
            :unit_symbol,
            presence: true

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

  validates :line_number,
            uniqueness: {
              scope: :purchase_id
            }

  validate :relationships_share_organization

  scope :ordered,
        -> { order(:line_number) }
  def returned_quantity(excluding_return: nil)
    relation =
      purchase_return_lines
        .joins(:purchase_return)
        .where(
          purchase_returns: {
            status: "completed"
          }
        )

    if excluding_return&.persisted?
      relation =
        relation.where.not(
          purchase_returns: {
            id: excluding_return.id
          }
        )
    end

    relation.sum(:quantity).to_d
  end

  def returnable_quantity(excluding_return: nil)
    [
      quantity.to_d -
        returned_quantity(
          excluding_return: excluding_return
        ),
      0.to_d
    ].max
  end

  private

  def relationships_share_organization
    [
      purchase,
      item,
      tax_rate
    ].compact.each do |record|
      next if record.organization_id ==
              organization_id

      errors.add(
        :base,
        "Purchase-line relationships must belong " \
        "to the same organization"
      )
    end
  end
end
