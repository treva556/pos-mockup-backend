class SalesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_organization!
  before_action :require_pos_access!

  def show
    scope =
      current_organization
        .sales
        .includes(
          :branch,
          :customer,
          :cashier,
          sale_lines: [
            :item,
            :tax_rate
          ],
          sale_payments: [
            :payment_method,
            :money_account,
            :recorded_by
          ]
        )

    if current_membership.cashier? &&
       current_membership.branch_id.present?
      scope =
        scope.where(
          branch_id:
            current_membership.branch_id
        )
    end

    @sale = scope.find(params[:id])
  end
end
