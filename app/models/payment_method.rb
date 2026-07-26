class PaymentMethod < ApplicationRecord
  belongs_to :organization

  has_many :branch_payment_settings,
           dependent: :restrict_with_error

  enum :payment_type, {
    cash: "cash",
    mobile_money: "mobile_money",
    bank_transfer: "bank_transfer",
    card: "card",
    credit: "credit",
    other: "other"
  }, default: :cash, validate: true

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

  scope :active, -> { where(active: true) }
  scope :alphabetical, -> { order(:name) }

  def money_account_required?
    !credit?
  end

  private

  def normalize_details
    self.name = name.to_s.strip
    self.code = code.to_s.strip.upcase
  end
end
