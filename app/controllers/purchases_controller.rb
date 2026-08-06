class PurchasesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_organization!
  before_action :require_supplier_management!

 def show
  @purchase =
    current_organization
      .purchases
      .includes(
        :branch,
        :supplier,
        :recorded_by,
        purchase_payments: [
          :payment_method,
          :money_account,
          :recorded_by
        ],
        purchase_lines: [
          :item,
          :tax_rate
        ]
      )
      .find(params[:id])

  if current_membership.branch_id.present? &&
     current_membership.branch_id !=
       @purchase.branch_id
    raise ActiveRecord::RecordNotFound
  end
 end
end
