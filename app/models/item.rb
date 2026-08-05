class Item < ApplicationRecord
  belongs_to :organization
  belongs_to :product_category, optional: true
  belongs_to :unit_of_measure
  belongs_to :tax_rate, optional: true

  has_many :stock_levels,
         dependent: :restrict_with_error

  has_many :stock_movements,
         dependent: :restrict_with_error

  has_many :stock_transfers,
         dependent: :restrict_with_error

  has_many :sale_lines,
         dependent: :restrict_with_error

  enum :item_type, {
    product: "product",
    service: "service"
  }, default: :product, validate: true

  before_validation :normalize_details
  before_validation :disable_inventory_for_services

  validates :name,
            presence: true

  validates :sku,
            uniqueness: {
              scope: :organization_id,
              case_sensitive: false
            },
            allow_blank: true

  validates :barcode,
            uniqueness: {
              scope: :organization_id
            },
            allow_blank: true

  validates :selling_price,
            numericality: {
              greater_than_or_equal_to: 0
            }

  validates :purchase_cost,
            numericality: {
              greater_than_or_equal_to: 0
            }

  validate :category_belongs_to_organization
  validate :unit_belongs_to_organization
  validate :tax_rate_belongs_to_organization

  scope :active, -> { where(active: true) }
  scope :alphabetical, -> { order(:name) }
  scope :products, -> { where(item_type: "product") }
  scope :services, -> { where(item_type: "service") }
  scope :stock_tracked, -> { where(track_inventory: true) }

  def stockable?
    product? && track_inventory?
  end

  private

  def normalize_details
    self.name = name.to_s.strip
    self.description = description.to_s.strip.presence
    self.sku = sku.to_s.strip.upcase.presence
    self.barcode = barcode.to_s.strip.presence
  end

  def disable_inventory_for_services
    self.track_inventory = false if service?
  end

  def category_belongs_to_organization
    return if product_category.blank?

    return if product_category.organization_id ==
              organization_id

    errors.add(
      :product_category,
      "must belong to the same organization"
    )
  end

  def unit_belongs_to_organization
    return if unit_of_measure.blank?

    return if unit_of_measure.organization_id ==
              organization_id

    errors.add(
      :unit_of_measure,
      "must belong to the same organization"
    )
  end

  def tax_rate_belongs_to_organization
    return if tax_rate.blank?

    return if tax_rate.organization_id ==
              organization_id

    errors.add(
      :tax_rate,
      "must belong to the same organization"
    )
  end
end
