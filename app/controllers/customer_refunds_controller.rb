class CustomerRefundsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_organization!
  before_action :require_customer_refund_management!
  before_action :set_sale_return

  def new
    load_refund_options
  end

  def create
    refund =
      Sales::RecordCustomerRefund.call(
        organization: current_organization,
        sale_return: @sale_return,
        recorded_by: current_user,
        payment_method:
          payment_method,
        money_account:
          money_account,
        amount:
          refund_params[:amount],
        refunded_at:
          refund_params[:refunded_at],
        reference:
          refund_params[:reference],
        notes:
          refund_params[:notes]
      )

    redirect_to sale_return_path(@sale_return),
                notice:
                  "Refund of KSh " \
                  "#{format('%.2f', refund.amount)} " \
                  "was recorded."
  rescue Sales::RefundError => error
    @error_message = error.message

    load_refund_options

    render :new,
           status: :unprocessable_entity
  end

  private

  def set_sale_return
    scope =
      current_organization
        .sale_returns
        .completed
        .includes(
          :branch,
          :sale
        )

    if current_membership.branch_id.present?
      scope =
        scope.where(
          branch_id:
            current_membership.branch_id
        )
    end

    @sale_return =
      scope.find(
        params[:sale_return_id]
      )

    @sale =
      @sale_return.sale
  end

  def load_refund_options
    @payment_methods =
      current_organization
        .payment_methods
        .active
        .order(:name)

    @money_accounts =
      current_organization
        .money_accounts
        .active
        .payable
        .where(
          branch_id: [
            nil,
            @sale_return.branch_id
          ]
        )
        .order(:name)
  end

  def payment_method
    current_organization
      .payment_methods
      .find(
        refund_params[
          :payment_method_id
        ]
      )
  end

  def money_account
    current_organization
      .money_accounts
      .find(
        refund_params[
          :money_account_id
        ]
      )
  end

  def refund_params
    params
      .require(:customer_refund)
      .permit(
        :payment_method_id,
        :money_account_id,
        :amount,
        :refunded_at,
        :reference,
        :notes
      )
  end
end
