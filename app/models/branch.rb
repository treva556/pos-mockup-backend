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

  validate :main_branch_must_remain_active

  before_validation :normalize_code

  scope :active, -> { where(active: true) }

  scope :main_first, lambda {
    order(main: :desc, name: :asc)
  }

  private

  def normalize_code
    self.code = code.to_s.strip.upcase
  end

  def main_branch_must_remain_active
    return unless main?
    return if active?

    errors.add(
      :active,
      "must remain enabled for the main branch"
    )
  end
end