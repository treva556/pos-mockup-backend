class MoneyTransfer < ApplicationRecord
  belongs_to :organization

  belongs_to :from_money_account,
             class_name: "MoneyAccount",
             inverse_of: :outgoing_money_transfers

  belongs_to :to_money_account,
             class_name: "MoneyAccount",
             inverse_of: :incoming_money_transfers

  belongs_to :recorded_by,
             class_name: "User",
             inverse_of: :recorded_money_transfers

  before_validation :normalize_details

  validates :amount,
            numericality: {
              greater_than: 0
            }

  validates :transferred_at,
            presence: true

  validate :accounts_are_different
  validate :from_account_belongs_to_organization
  validate :to_account_belongs_to_organization
  validate :recorded_by_belongs_to_organization
  validate :from_account_is_active
  validate :to_account_is_active
  validate :from_account_can_pay
  validate :to_account_can_receive
  validate :amount_does_not_exceed_source_balance

  scope :recent_first,
        lambda {
          order(
            transferred_at: :desc,
            created_at: :desc
          )
        }

  private

  def normalize_details
    self.reference =
      reference.to_s.strip.presence

    self.notes =
      notes.to_s.strip.presence
  end

  def accounts_are_different
    return if from_money_account.blank?
    return if to_money_account.blank?
    return unless from_money_account_id ==
                  to_money_account_id

    errors.add(
      :to_money_account,
      "must be different from the source account"
    )
  end

  def from_account_belongs_to_organization
    return if from_money_account.blank?
    return if organization.blank?

    return if from_money_account.organization_id ==
              organization_id

    errors.add(
      :from_money_account,
      "must belong to the same organization"
    )
  end

  def to_account_belongs_to_organization
    return if to_money_account.blank?
    return if organization.blank?

    return if to_money_account.organization_id ==
              organization_id

    errors.add(
      :to_money_account,
      "must belong to the same organization"
    )
  end


  def recorded_by_belongs_to_organization
    return if recorded_by.blank?
    return if organization.blank?

    return if organization
      .memberships
      .active
      .exists?(user_id: recorded_by_id)

    errors.add(
      :recorded_by,
      "must be an active member of the organization"
    )
  end

  def from_account_is_active
    return if from_money_account.blank?
    return if from_money_account.active?

    errors.add(
      :from_money_account,
      "must be active"
    )
  end

  def to_account_is_active
    return if to_money_account.blank?
    return if to_money_account.active?

    errors.add(
      :to_money_account,
      "must be active"
    )
  end

  def from_account_can_pay
    return if from_money_account.blank?
    return if from_money_account.can_pay?

    errors.add(
      :from_money_account,
      "must be able to make payments"
    )
  end

  def to_account_can_receive
    return if to_money_account.blank?
    return if to_money_account.can_receive?

    errors.add(
      :to_money_account,
      "must be able to receive money"
    )
  end

  def amount_does_not_exceed_source_balance
    return if from_money_account.blank?
    return if amount.blank?
    return if amount.to_d <= from_money_account.current_balance

    errors.add(
        :amount,
        "cannot exceed the source account balance"
    )
    end
end
