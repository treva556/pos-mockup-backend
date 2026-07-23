class Branch < ApplicationRecord
  belongs_to :organization

  has_many :memberships, dependent: :restrict_with_error

  validates :name, presence: true
  validates :code,
            presence: true,
            uniqueness: {
              scope: :organization_id,
              case_sensitive: false
            }

  before_validation :normalize_code

  scope :active, -> { where(active: true) }

  private

  def normalize_code
    self.code = code.to_s.strip.upcase
  end
end