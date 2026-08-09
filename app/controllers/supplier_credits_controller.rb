class SupplierCreditsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_organization!
  before_action :require_supplier_credit_management!
  before_action :set_purchase_return

  def new
    unless @purchase_return
             .uncredited_balance
             .positive?
      redirect_to purchase_return_path(
        @purchase_return
      ),
                  alert:
                    "This return has no supplier credit " \
                    "waiting to be recorded."
    end
  end

  def create
    credit =
      Purchases::RecordSupplierCredit.call(
        organization: current_organization,
        purchase_return: @purchase_return,
        recorded_by: current_user,
        amount:
          supplier_credit_params[:amount],
        credit_number:
          supplier_credit_params[:credit_number],
        issued_on:
          supplier_credit_params[:issued_on],
        notes:
          supplier_credit_params[:notes]
      )

    redirect_to purchase_return_path(
      @purchase_return
    ),
                notice:
                  "Supplier credit #{credit.credit_number} " \
                  "was recorded."
  rescue Purchases::SupplierCreditError => error
    @error_message = error.message

    render :new,
           status: :unprocessable_entity
  end

  private

  def set_purchase_return
    scope =
      current_organization
        .purchase_returns
        .completed
        .includes(
          :branch,
          purchase: :supplier
        )

    if current_membership.branch_id.present?
      scope =
        scope.where(
          branch_id:
            current_membership.branch_id
        )
    end

    @purchase_return =
      scope.find(
        params[:purchase_return_id]
      )

    @purchase =
      @purchase_return.purchase
  end

  def supplier_credit_params
    params
      .require(:supplier_credit)
      .permit(
        :amount,
        :credit_number,
        :issued_on,
        :notes
      )
  end
end
