class Organization < ApplicationRecord
  has_many :branches, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :customers,
         dependent: :restrict_with_error

  has_many :suppliers,
          dependent: :restrict_with_error
   has_many :product_categories,
         dependent: :restrict_with_error

    has_many :unit_of_measures,
            dependent: :restrict_with_error

    has_many :tax_rates,
            dependent: :restrict_with_error

    has_many :items,
            dependent: :restrict_with_error

  has_many :money_accounts,
          dependent: :restrict_with_error

  has_many :payment_methods,
          dependent: :restrict_with_error

  has_many :branch_payment_settings,
          dependent: :restrict_with_error

  has_many :money_transfers,
         dependent: :restrict_with_error

  has_many :stock_levels,
         dependent: :restrict_with_error

  has_many :stock_movements,
         dependent: :restrict_with_error

  has_many :stock_transfers,
         dependent: :restrict_with_error

  has_many :sales,
         dependent: :restrict_with_error

  has_many :sale_lines,
          dependent: :restrict_with_error

  has_many :sale_payments,
          dependent: :restrict_with_error

  before_validation :normalize_business_details

  validates :name, presence: true

  validates :email,
            format: { with: URI::MailTo::EMAIL_REGEXP },
            allow_blank: true

  validates :country_code,
            presence: true,
            length: { is: 2 }

  validates :currency_code,
            presence: true,
            length: { is: 3 }

  validates :time_zone, presence: true

  validates :kra_pin,
            uniqueness: { case_sensitive: false },
            allow_blank: true

  validates :receipt_footer,
            length: { maximum: 250 },
            allow_blank: true

  scope :active, -> { where(active: true) }

  def main_branch
    branches.find_by(main: true)
  end

  private

  def normalize_business_details
    self.name = name.to_s.strip
    self.legal_name = legal_name.to_s.strip.presence
    self.phone = phone.to_s.strip.presence
    self.email = email.to_s.strip.downcase.presence

    self.registration_number =
      registration_number.to_s.strip.upcase.presence

    self.kra_pin =
      kra_pin.to_s.strip.upcase.presence

    self.country_code =
      country_code.to_s.strip.upcase

    self.currency_code =
      currency_code.to_s.strip.upcase

    self.address =
      address.to_s.strip.presence

    self.receipt_footer =
      receipt_footer.to_s.strip.presence
  end
end
