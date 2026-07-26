class BranchPaymentSetting < ApplicationRecord
  belongs_to :organization
  belongs_to :branch
  belongs_to :payment_method
  belongs_to :money_account, optional: true

  validates :payment_method_id,
            uniqueness: {
              scope: :branch_id
            }

  validate :branch_belongs_to_organization
  validate :payment_method_belongs_to_organization
  validate :money_account_belongs_to_organization
  validate :money_account_matches_branch
  validate :money_account_is_receivable
  validate :money_account_is_present_when_required
  validate :payment_method_is_active_when_enabled
  validate :money_account_is_active_when_enabled

  scope :enabled, -> { where(enabled: true) }

  private

  def branch_belongs_to_organization
    return if branch.blank?
    return if branch.organization_id == organization_id

    errors.add(
      :branch,
      "must belong to the same organization"
    )
  end

  def payment_method_belongs_to_organization
    return if payment_method.blank?

    return if payment_method.organization_id ==
              organization_id

    errors.add(
      :payment_method,
      "must belong to the same organization"
    )
  end

  def money_account_belongs_to_organization
    return if money_account.blank?

    return if money_account.organization_id ==
              organization_id

    errors.add(
      :money_account,
      "must belong to the same organization"
    )
  end

  def money_account_matches_branch
    return if money_account.blank?
    return if money_account.branch_id.nil?
    return if money_account.branch_id == branch_id

    errors.add(
      :money_account,
      "must be organization-wide or belong to the selected branch"
    )
  end

  def money_account_is_receivable
    return unless enabled?
    return if money_account.blank?
    return if money_account.can_receive?

    errors.add(
      :money_account,
      "must be able to receive payments"
    )
  end

  def money_account_is_present_when_required
    return unless enabled?
    return if payment_method.blank?
    return unless payment_method.money_account_required?
    return if money_account.present?

    errors.add(
      :money_account,
      "must be selected for this payment method"
    )
  end

  def payment_method_is_active_when_enabled
      return unless enabled?
      return if payment_method.blank?
      return if payment_method.active?

      errors.add(
        :payment_method,
        "must be active when the setting is enabled"
      )
    end

    def money_account_is_active_when_enabled
      return unless enabled?
      return if money_account.blank?
      return if money_account.active?

      errors.add(
        :money_account,
        "must be active when the setting is enabled"
      )
    end
end
