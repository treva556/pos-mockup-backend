class AccountingAccountMapping < ApplicationRecord
  ROLES = {
    accounts_receivable: "accounts_receivable",
    inventory: "inventory",
    supplier_credit_receivable: "supplier_credit_receivable",
    accounts_payable: "accounts_payable",
    customer_refund_payable: "customer_refund_payable",
    sales_revenue: "sales_revenue",
    sales_returns: "sales_returns",
    cost_of_goods_sold: "cost_of_goods_sold",
    input_tax: "input_tax",
    output_tax: "output_tax",
    retained_earnings: "retained_earnings",
    opening_balance_equity: "opening_balance_equity",
    inventory_adjustment_gain: "inventory_adjustment_gain",
    inventory_adjustment_loss: "inventory_adjustment_loss"
  }.freeze

  belongs_to :organization

  belongs_to :ledger_account,
             inverse_of: :accounting_account_mappings

  enum :role,
       ROLES,
       prefix: true,
       validate: true

  validates :role,
            presence: true,
            uniqueness: {
              scope: :organization_id
            }

  validate :ledger_account_belongs_to_organization
  validate :ledger_account_is_postable
  validate :ledger_account_is_active

  private

  def ledger_account_belongs_to_organization
    return if ledger_account.blank?
    return if organization.blank?

    return if ledger_account.organization_id ==
              organization_id

    errors.add(
      :ledger_account,
      "must belong to the same organization"
    )
  end

  def ledger_account_is_postable
    return if ledger_account.blank?
    return if ledger_account.postable?

    errors.add(
      :ledger_account,
      "must be a postable account"
    )
  end

  def ledger_account_is_active
    return if ledger_account.blank?
    return if ledger_account.active?

    errors.add(
      :ledger_account,
      "must be active"
    )
  end
end
