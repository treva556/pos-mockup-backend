class Expense < ApplicationRecord
  belongs_to :organization

  belongs_to :branch,
             optional: true

  belongs_to :expense_account,
             class_name: "LedgerAccount"

  belongs_to :money_account

  belongs_to :recorded_by,
             class_name: "User"

  belongs_to :reversed_by,
            class_name: "User",
            optional: true

  has_one :journal_entry,
          as: :source,
          dependent: :restrict_with_error

  validates :expense_date,
            presence: true

  validates :amount,
            numericality: {
              greater_than: 0
            }

  validates :payee,
            length: {
              maximum: 150
            },
            allow_blank: true

  validates :reference,
            length: {
              maximum: 100
            },
            allow_blank: true

  validate :branch_belongs_to_organization
  validate :expense_account_belongs_to_organization
  validate :expense_account_is_valid
  validate :money_account_belongs_to_organization
  validate :money_account_is_payable
  validate :recorded_by_is_active_member
  validate :reversal_details_are_consistent

  enum :status,
     {
       posted: "posted",
       reversed: "reversed"
     },
     default: :posted,
     prefix: true,
     validate: true

  scope :recent_first,
        -> {
          order(
            expense_date: :desc,
            created_at: :desc
          )
        }

  scope :posted_expenses,
        -> { where(status: "posted") }

  scope :reversed_expenses,
        -> { where(status: "reversed") }

  private

  def branch_belongs_to_organization
    return if branch.blank?
    return if organization.blank?

    return if branch.organization_id ==
              organization_id

    errors.add(
      :branch,
      "must belong to the same organization"
    )
  end

  def expense_account_belongs_to_organization
    return if expense_account.blank?
    return if organization.blank?

    return if expense_account.organization_id ==
              organization_id

    errors.add(
      :expense_account,
      "must belong to the same organization"
    )
  end

  def expense_account_is_valid
    return if expense_account.blank?

    unless expense_account.account_type_expense?
      errors.add(
        :expense_account,
        "must be an expense account"
      )
    end

    unless expense_account.postable?
      errors.add(
        :expense_account,
        "must be postable"
      )
    end

    return if expense_account.active?

    errors.add(
      :expense_account,
      "must be active"
    )
  end

  def money_account_belongs_to_organization
    return if money_account.blank?
    return if organization.blank?

    return if money_account.organization_id ==
              organization_id

    errors.add(
      :money_account,
      "must belong to the same organization"
    )
  end

  def money_account_is_payable
    return if money_account.blank?

    unless money_account.active?
      errors.add(
        :money_account,
        "must be active"
      )
    end

    return if money_account.can_pay?

    errors.add(
      :money_account,
      "must allow payments"
    )
  end

  def reversal_details_are_consistent
    if status_reversed?
      errors.add(
        :reversed_at,
        "must be present when expense is reversed"
      ) if reversed_at.blank?

      errors.add(
        :reversed_by,
        "must be present when expense is reversed"
      ) if reversed_by.blank?
    elsif reversed_at.present? ||
          reversed_by.present?
      errors.add(
        :status,
        "must be reversed when reversal details are present"
      )
    end
  end

  def recorded_by_is_active_member
    return if recorded_by.blank?
    return if organization.blank?

    return if organization
      .memberships
      .active
      .exists?(
        user_id:
          recorded_by.id
      )

    errors.add(
      :recorded_by,
      "must be an active organization member"
    )
  end
end
