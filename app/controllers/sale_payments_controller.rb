class SalePaymentsController <
  ApplicationController
  before_action :authenticate_user!
  before_action :require_organization!
  before_action :require_customer_payment_management!
  before_action :set_sale
  before_action :load_payment_options

  def new
    @payment =
      @sale.sale_payments.new(
        amount: @sale.balance_due,
        amount_tendered:
          @sale.balance_due,
        paid_at: Time.current
      )
  end

  def create
    payment =
      Sales::RecordCustomerPayment.call(
        organization: current_organization,
        sale: @sale,
        recorded_by: current_user,
        payment_method:
          @payment_methods.find(
            payment_params[:payment_method_id]
          ),
        money_account:
          @money_accounts.find(
            payment_params[:money_account_id]
          ),
        amount: payment_params[:amount],
        amount_tendered:
          payment_params[:amount_tendered],
        paid_at: payment_params[:paid_at],
        reference: payment_params[:reference],
        notes: payment_params[:notes]
      )

    redirect_to sale_path(@sale),
                notice:
                  "Payment of KSh #{payment.amount} was recorded."
  rescue Sales::InvalidCustomerPaymentError,
         ActiveRecord::RecordNotFound => error
    redirect_to new_sale_payment_path(@sale),
                alert: error.message
  rescue ActiveRecord::RecordInvalid => error
    redirect_to new_sale_payment_path(@sale),
                alert:
                  error.record
                    .errors
                    .full_messages
                    .to_sentence
  end

  private

  def set_sale
    scope =
      current_organization
        .sales
        .completed
        .where.not(customer_id: nil)
        .where("balance_due > 0")

    if current_membership.cashier? &&
       current_membership.branch_id.present?
      scope =
        scope.where(
          branch_id:
            current_membership.branch_id
        )
    end

    @sale =
      scope
        .includes(
          :customer,
          :branch
        )
        .find(params[:sale_id])
  end

  def load_payment_options
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
      .require(:sale_payment)
      .permit(
        :payment_method_id,
        :money_account_id,
        :amount,
        :amount_tendered,
        :paid_at,
        :reference,
        :notes
      )
  end
end
