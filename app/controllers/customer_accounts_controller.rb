class CustomerAccountsController <
  ApplicationController
  before_action :authenticate_user!
  before_action :require_organization!
  before_action :require_customer_account_view!

  def show
    @customer =
      current_organization
        .customers
        .find(params[:customer_id])

    base_scope =
      @customer
        .sales
        .completed
        .includes(
          :branch,
          :cashier
        )

    if current_membership.cashier? &&
       current_membership.branch_id.present?
      base_scope =
        base_scope.where(
          branch_id:
            current_membership.branch_id
        )
    end

    @outstanding_balance =
      base_scope.sum(:balance_due)

    @overdue_balance =
      base_scope
        .where("balance_due > 0")
        .where("due_on < ?", Date.current)
        .sum(:balance_due)

    @sales =
      base_scope.recent_first
  end
end
