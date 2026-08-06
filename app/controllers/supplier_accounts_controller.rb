class SupplierAccountsController <
  ApplicationController
  before_action :authenticate_user!
  before_action :require_organization!
  before_action :require_supplier_account_view!

  def show
    @supplier =
      current_organization
        .suppliers
        .find(params[:supplier_id])

    @purchases =
      visible_purchases
        .where(supplier: @supplier)
        .received
        .includes(:branch)
        .recent_first

    @total_purchases =
      @purchases.sum(:total).to_d

    @total_paid =
      @purchases.sum(:amount_paid).to_d

    @outstanding_balance =
      @purchases.sum(:balance_due).to_d

    @overdue_balance =
      @purchases
        .where("balance_due > 0")
        .where("due_on < ?", Date.current)
        .sum(:balance_due)
        .to_d
  end

  private

  def visible_purchases
    scope =
      current_organization.purchases

    return scope if
      current_membership.branch_id.blank?

    scope.where(
      branch_id:
        current_membership.branch_id
    )
  end
end
