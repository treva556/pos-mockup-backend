class PurchasePaymentsController <
  ApplicationController
  before_action :authenticate_user!
  before_action :require_organization!
  before_action :require_supplier_payment_management!
  before_action :set_purchase
  before_action :load_form_options

  def new
  end

  def create
    payment_method =
      current_organization
        .payment_methods
        .find(payment_params[:payment_method_id])

    money_account =
      current_organization
        .money_accounts
        .find(payment_params[:money_account_id])

    Purchases::RecordSupplierPayment.call(
      organization: current_organization,
      purchase: @purchase,
      payment_method: payment_method,
      money_account: money_account,
      recorded_by: current_user,
      amount: payment_params[:amount],
      paid_at:
        payment_params[:paid_at].presence ||
          Time.current,
      reference: payment_params[:reference],
      notes: payment_params[:notes]
    )

    redirect_to purchase_path(@purchase),
                notice:
                  "Supplier payment was recorded."
  rescue Purchases::InvalidSupplierPaymentError,
         ActiveRecord::RecordInvalid => error
    flash.now[:alert] =
      if error.respond_to?(:record)
        error.record.errors.full_messages.to_sentence
      else
        error.message
      end

    render :new,
           status: :unprocessable_entity
  end

  private

  def set_purchase
    scope =
      current_organization
        .purchases
        .includes(
          :supplier,
          :branch,
          :purchase_payments
        )

    if current_membership.branch_id.present?
      scope =
        scope.where(
          branch_id:
            current_membership.branch_id
        )
    end

    @purchase =
      scope.find(params[:purchase_id])
  end

  def load_form_options
    @payment_methods =
      current_organization
        .payment_methods
        .where(active: true)
        .order(:name)

    @money_accounts =
      current_organization
        .money_accounts
        .where(active: true)
        .order(:name)
  end

  def payment_params
    params
      .require(:purchase_payment)
      .permit(
        :payment_method_id,
        :money_account_id,
        :amount,
        :paid_at,
        :reference,
        :notes
      )
  end
end
