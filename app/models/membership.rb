class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :organization
  belongs_to :branch, optional: true

  enum :role, {
    owner: "owner",
    admin: "admin",
    manager: "manager",
    cashier: "cashier",
    accountant: "accountant",
    stock_clerk: "stock_clerk"
  }, default: :cashier, validate: true

  validates :user_id,
            uniqueness: {
              scope: :organization_id,
              message: "already belongs to this organization"
            }

  validate :branch_belongs_to_organization

  scope :active, -> { where(active: true) }

  def organization_admin?
    owner? || admin?
  end

  private

  def branch_belongs_to_organization
    return if branch.blank?
    return if branch.organization_id == organization_id

    errors.add(
      :branch,
      "must belong to the same organization"
    )
  end
end