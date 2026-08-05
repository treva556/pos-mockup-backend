module Pos
  class CheckoutPaymentsController < BaseController
    before_action :require_nonempty_cart

    def create
      pos_payment_plan.add_entry(
        payment_method_id:
          checkout_payment_params[
            :payment_method_id
          ],
        money_account_id:
          checkout_payment_params[
            :money_account_id
          ],
        amount:
          checkout_payment_params[:amount],
        amount_tendered:
          checkout_payment_params[
            :amount_tendered
          ],
        reference:
          checkout_payment_params[:reference],
        notes:
          checkout_payment_params[:notes]
      )

      persist_pos_payment_plan!

      redirect_to checkout_path,
                  notice: "Payment was added."
    rescue Sales::InvalidPaymentError => error
      redirect_to checkout_path,
                  alert: error.message
    end

    def update
      pos_payment_plan.update_entry(
        entry_id: params[:entry_id],
        payment_method_id:
          checkout_payment_params[
            :payment_method_id
          ],
        money_account_id:
          checkout_payment_params[
            :money_account_id
          ],
        amount:
          checkout_payment_params[:amount],
        amount_tendered:
          checkout_payment_params[
            :amount_tendered
          ],
        reference:
          checkout_payment_params[:reference],
        notes:
          checkout_payment_params[:notes]
      )

      persist_pos_payment_plan!

      redirect_to checkout_path,
                  notice: "Payment was updated."
    rescue Sales::InvalidPaymentError => error
      redirect_to checkout_path,
                  alert: error.message
    end

    def destroy
      pos_payment_plan.remove_entry(
        entry_id: params[:entry_id]
      )

      persist_pos_payment_plan!

      redirect_to checkout_path,
                  notice: "Payment was removed."
    end

    private

    def require_nonempty_cart
      return unless pos_cart.empty?

      redirect_to pos_sale_path,
                  alert:
                    "Add at least one item before continuing."
    end

    def checkout_path
      pos_checkout_path(
        branch_id: @pos_branch.id
      )
    end

    def checkout_payment_params
      params
        .require(:checkout_payment)
        .permit(
          :payment_method_id,
          :money_account_id,
          :amount,
          :amount_tendered,
          :reference,
          :notes
        )
    end
  end
end
