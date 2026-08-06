module Purchasing
  class CartsController < BaseController
    def update
      purchase_cart.supplier_id =
        cart_params[:supplier_id]

      purchase_cart.supplier_invoice_number =
        cart_params[:supplier_invoice_number]

      purchase_cart.purchased_on =
        cart_params[:purchased_on]

      purchase_cart.due_on =
        cart_params[:due_on]

      purchase_cart.notes =
        cart_params[:notes]

      purchase_cart.supplier

      persist_purchase_cart!

      redirect_to purchase_path,
                  notice:
                    "Purchase details were saved."
    rescue Purchases::ReceivingError => error
      redirect_to purchase_path,
                  alert: error.message
    end

    def destroy
      clear_purchase_cart!

      redirect_to purchase_path,
                  notice:
                    "Purchase cart was cleared."
    end

    private

    def purchase_path
      new_purchasing_purchase_path(
        branch_id: @purchase_branch.id
      )
    end

    def cart_params
      params
        .require(:purchase_cart)
        .permit(
          :supplier_id,
          :supplier_invoice_number,
          :purchased_on,
          :due_on,
          :notes
        )
    end
  end
end
