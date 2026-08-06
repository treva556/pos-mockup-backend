class User < ApplicationRecord
  has_secure_password

  has_many :memberships, dependent: :destroy
  has_many :organizations, through: :memberships
  has_many :recorded_money_transfers,
            class_name: "MoneyTransfer",
            foreign_key: :recorded_by_id,
            inverse_of: :recorded_by,
            dependent: :restrict_with_error
  has_many :recorded_stock_movements,
            class_name: "StockMovement",
            foreign_key: :recorded_by_id,
            inverse_of: :recorded_by,
            dependent: :restrict_with_error

  has_many :recorded_stock_transfers,
            class_name: "StockTransfer",
            foreign_key: :recorded_by_id,
            inverse_of: :recorded_by,
            dependent: :restrict_with_error

  has_many :cashier_sales,
            class_name: "Sale",
            foreign_key: :cashier_id,
            inverse_of: :cashier,
            dependent: :restrict_with_error

  has_many :recorded_sale_payments,
            class_name: "SalePayment",
            foreign_key: :recorded_by_id,
            inverse_of: :recorded_by,
            dependent: :restrict_with_error

  has_many :recorded_purchases,
            class_name: "Purchase",
            foreign_key: :recorded_by_id,
            inverse_of: :recorded_by,
            dependent: :restrict_with_error

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
