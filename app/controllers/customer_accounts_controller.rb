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
          :cashier,
          :sale_returns
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
      base_scope.sum do |sale|
        sale.effective_balance_due
      end

    @overdue_balance =
      base_scope
        .where("due_on < ?", Date.current)
        .sum do |sale|
          sale.effective_balance_due
        end

    @sales =
      base_scope.recent_first
  end
end
