class Customer < ApplicationRecord
  belongs_to :organization

  before_validation :normalize_details

  validates :name,
            presence: true

  validates :email,
            format: {
              with: URI::MailTo::EMAIL_REGEXP
            },
            allow_blank: true

  validates :kra_pin,
            uniqueness: {
              scope: :organization_id,
              case_sensitive: false
            },
            allow_blank: true

  validates :credit_limit,
            numericality: {
              greater_than_or_equal_to: 0
            }

  validates :payment_terms_days,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 0
            }

  scope :active, -> { where(active: true) }

  scope :alphabetical, -> { order(:name) }

  private

  def normalize_details
    self.name = name.to_s.strip
    self.phone = phone.to_s.strip.presence
    self.email = email.to_s.strip.downcase.presence
    self.kra_pin = kra_pin.to_s.strip.upcase.presence
    self.address = address.to_s.strip.presence
    self.notes = notes.to_s.strip.presence
  end
end
