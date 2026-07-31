module Pos
  class CartsController < BaseController
    def update
      pos_cart.customer_id =
        cart_params[:customer_id]

      persist_pos_cart!

      redirect_to pos_sale_path,
                  notice: "Customer selection was updated."
    rescue ActiveRecord::RecordNotFound
      redirect_to pos_sale_path,
                  alert: "The selected customer is unavailable."
    end

    def destroy
      clear_pos_cart!

      redirect_to pos_sale_path,
                  notice: "The cart was cleared."
    end

    private

    def cart_params
      params
        .require(:cart)
        .permit(:customer_id)
    end
  end
end
