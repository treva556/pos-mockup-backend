class MoneyAccount < ApplicationRecord
  belongs_to :organization
  belongs_to :branch, optional: true

  has_many :branch_payment_settings,
           dependent: :restrict_with_error

  has_many :outgoing_money_transfers,
            class_name: "MoneyTransfer",
            foreign_key: :from_money_account_id,
            inverse_of: :from_money_account,
            dependent: :restrict_with_error

  has_many :incoming_money_transfers,
            class_name: "MoneyTransfer",
            foreign_key: :to_money_account_id,
            inverse_of: :to_money_account,
            dependent: :restrict_with_error

  has_many :sale_payments,
            dependent: :restrict_with_error

  has_many :purchase_payments,
            dependent: :restrict_with_error

  enum :account_type, {
    cash: "cash",
    petty_cash: "petty_cash",
    mpesa_till: "mpesa_till",
    mpesa_paybill: "mpesa_paybill",
    bank: "bank",
    card_clearing: "card_clearing",
    mobile_wallet: "mobile_wallet",
    other: "other"
  }, default: :cash, validate: true

  before_validation :normalize_details

  validates :name,
            presence: true,
            uniqueness: {
              scope: :organization_id,
              case_sensitive: false
            }

  validates :account_number,
            uniqueness: {
              scope: :organization_id,
              case_sensitive: false
            },
            allow_blank: true

  validates :opening_balance,
            numericality: true

  validate :branch_belongs_to_organization
  validate :opening_balance_date_is_present

  scope :active, -> { where(active: true) }
  scope :alphabetical, -> { order(:name) }
  scope :receivable, -> { where(can_receive: true) }
  scope :payable, -> { where(can_pay: true) }

  def organization_wide?
    branch_id.nil?
  end

  def incoming_transfer_total
      incoming_money_transfers.sum(:amount)
  end

  def outgoing_transfer_total
      outgoing_money_transfers.sum(:amount)
  end

  def balance_before_purchase_disbursements
  opening_balance.to_d +
      incoming_transfer_total -
      outgoing_transfer_total +
      sale_receipts_total
  end

  def current_balance
    balance_before_purchase_disbursements -
      purchase_disbursements_total
  end

  def purchase_disbursements_total
    purchase_payments
      .sum(:amount)
      .to_d
  end

  def sale_receipts_total
    sale_payments.sum(:amount)
  end

  private

  def normalize_details
    self.name = name.to_s.strip

    self.account_number =
      account_number.to_s.strip.upcase.presence

    self.notes = notes.to_s.strip.presence
  end

  def branch_belongs_to_organization
    return if branch.blank?
    return if branch.organization_id == organization_id

    errors.add(
      :branch,
      "must belong to the same organization"
    )
  end

  def opening_balance_date_is_present
    return if opening_balance.to_d.zero?
    return if opening_balance_date.present?

    errors.add(
      :opening_balance_date,
      "must be provided when an opening balance is entered"
    )
  end
end
