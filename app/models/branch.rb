class Branch < ApplicationRecord
  belongs_to :organization

  has_many :memberships, dependent: :restrict_with_error

  has_many :money_accounts,
         dependent: :restrict_with_error

  has_many :branch_payment_settings,
          dependent: :restrict_with_error

  validates :name, presence: true

  validates :code,
            presence: true,
            uniqueness: {
              scope: :organization_id,
              case_sensitive: false
            }

  validate :main_branch_must_remain_active

  validate :inactive_branch_cannot_have_active_members

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
  def inactive_branch_cannot_have_active_members
    return unless persisted?
    return if active?
    return unless memberships.active.exists?

    errors.add(
      :active,
      "cannot be disabled while active team members are assigned"
    )
  end
end
