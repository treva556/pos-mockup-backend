module Pos
  class CartItemsController < BaseController
    def create
      item =
        current_organization
          .items
          .active
          .find(cart_item_params[:item_id])

      pos_cart.add_item(
        item: item,
        quantity:
          cart_item_params[:quantity].presence || 1
      )

      clear_pos_payment_plan!

      persist_pos_cart!

      redirect_to pos_sale_path,
                  notice:
                    "#{item.name} was added to the cart."
    rescue Sales::InvalidLineError => error
      redirect_to pos_sale_path,
                  alert: error.message
    end

    def update
      pos_cart.update_item(
        item_id: params[:item_id],
        quantity: cart_item_params[:quantity],
        discount_amount:
          cart_item_params[:discount_amount]
      )

      clear_pos_payment_plan!
      persist_pos_cart!

      redirect_to pos_sale_path,
                  notice: "Cart item was updated."
    rescue Sales::InvalidLineError => error
      redirect_to pos_sale_path,
                  alert: error.message
    end

    def destroy
      pos_cart.remove_item(
        item_id: params[:item_id]
      )

      clear_pos_payment_plan!
      persist_pos_cart!

      redirect_to pos_sale_path,
                  notice: "Item was removed from the cart."
    end

    private

    def cart_item_params
      params
        .require(:cart_item)
        .permit(
          :item_id,
          :quantity,
          :discount_amount
        )
    end
  end
end
