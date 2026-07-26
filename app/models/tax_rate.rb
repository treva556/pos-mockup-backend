class TaxRate < ApplicationRecord
  belongs_to :organization

  has_many :items,
           dependent: :restrict_with_error

  enum :tax_type, {
    standard: "standard",
    zero_rated: "zero_rated",
    exempt: "exempt",
    non_vatable: "non_vatable"
  }, default: :standard, validate: true

  before_validation :normalize_details

  validates :name,
            presence: true,
            uniqueness: {
              scope: :organization_id,
              case_sensitive: false
            }

  validates :code,
            presence: true,
            uniqueness: {
              scope: :organization_id,
              case_sensitive: false
            }

  validates :rate,
            numericality: {
              greater_than_or_equal_to: 0,
              less_than_or_equal_to: 100
            }

  scope :active, -> { where(active: true) }
  scope :alphabetical, -> { order(:name) }

  private

  def normalize_details
    self.name = name.to_s.strip
    self.code = code.to_s.strip.upcase
  end
end
