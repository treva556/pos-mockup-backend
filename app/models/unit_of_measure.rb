class UnitOfMeasure < ApplicationRecord
  belongs_to :organization

  has_many :items,
           dependent: :restrict_with_error

  before_validation :normalize_details

  validates :name,
            presence: true,
            uniqueness: {
              scope: :organization_id,
              case_sensitive: false
            }

  validates :symbol,
            presence: true,
            uniqueness: {
              scope: :organization_id,
              case_sensitive: false
            }

  scope :active, -> { where(active: true) }
  scope :alphabetical, -> { order(:name) }

  private

  def normalize_details
    self.name = name.to_s.strip
    self.symbol = symbol.to_s.strip
  end
end
