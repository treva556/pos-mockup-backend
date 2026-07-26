class Membership < ApplicationRecord
  ORGANIZATION_WIDE_ROLES = %w[owner admin].freeze
  BRANCH_REQUIRED_ROLES = %w[cashier stock_clerk].freeze
  TEAM_ROLES = %w[
    admin
    manager
    cashier
    accountant
    stock_clerk
  ].freeze

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
  validate :branch_assignment_matches_role

  scope :active, -> { where(active: true) }

  def organization_admin?
    owner? || admin?
  end

  def branch_restricted?
    branch_id.present?
  end

  def supplier_management?
    owner? ||
      admin? ||
      manager? ||
      accountant? ||
      stock_clerk?
  end

  def product_setup_management?
    owner? ||
      admin? ||
      manager? ||
      accountant? ||
      stock_clerk?
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

  def branch_assignment_matches_role
    return if role.blank?

    if ORGANIZATION_WIDE_ROLES.include?(role) && branch.present?
      errors.add(
        :branch,
        "must be blank for owners and administrators"
      )
    end

    if BRANCH_REQUIRED_ROLES.include?(role) && branch.blank?
      errors.add(
        :branch,
        "must be selected for cashiers and stock clerks"
      )
    end
  end
end
