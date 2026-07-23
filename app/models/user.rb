class User < ApplicationRecord
  has_secure_password

  has_many :memberships, dependent: :destroy
  has_many :organizations, through: :memberships

  enum :platform_role, {
    regular: "regular",
    support: "support",
    super_admin: "super_admin"
  }, default: :regular, validate: true

  scope :active, -> { where(active: true) }

  before_validation :normalize_email

  validates :name, presence: true

  validates :email,
            presence: true,
            uniqueness: { case_sensitive: false },
            format: { with: URI::MailTo::EMAIL_REGEXP }

  validates :password,
            length: { minimum: 8 },
            allow_nil: true

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end
end