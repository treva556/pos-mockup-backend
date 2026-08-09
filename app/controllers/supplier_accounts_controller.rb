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
        .includes(
          :branch,
          purchase_returns:
            :supplier_credits
        )
        .recent_first

    @total_purchases =
      @purchases.sum(:total).to_d

    @total_paid =
      @purchases.sum(:amount_paid).to_d

    @total_returns =
      @purchases.sum do |purchase|
        purchase.completed_return_total
      end

    @outstanding_balance =
      @purchases.sum do |purchase|
        purchase.effective_balance_due
      end

    @overdue_balance =
      @purchases
        .select(&:overdue?)
        .sum do |purchase|
          purchase.effective_balance_due
        end

    @available_credit_balance =
      @purchases.sum do |purchase|
        purchase
          .purchase_returns
          .select(&:completed?)
          .sum do |purchase_return|
            purchase_return
              .supplier_credits
              .select do |credit|
                credit.available? ||
                  credit.partially_applied?
              end
              .sum(&:available_amount)
          end
      end
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
