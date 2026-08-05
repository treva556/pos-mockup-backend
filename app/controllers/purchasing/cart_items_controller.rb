module Purchasing
  class CartItemsController < BaseController
    def create
      item =
        current_organization
          .items
          .find(
            cart_item_params[:item_id]
          )

      purchase_cart.add_item(
        item: item,
        quantity:
          cart_item_params[:quantity],
        unit_cost:
          cart_item_params[:unit_cost]
      )

      persist_purchase_cart!

      redirect_to purchase_path,
                  notice:
                    "#{item.name} was added."
    rescue Purchases::InvalidLineError => error
      redirect_to purchase_path,
                  alert: error.message
    end

    def update
      purchase_cart.update_item(
        item_id: params[:item_id],
        quantity:
          cart_item_params[:quantity],
        unit_cost:
          cart_item_params[:unit_cost],
        discount_amount:
          cart_item_params[
            :discount_amount
          ]
      )

      persist_purchase_cart!

      redirect_to purchase_path,
                  notice:
                    "Purchase item was updated."
    rescue Purchases::InvalidLineError => error
      redirect_to purchase_path,
                  alert: error.message
    end

    def destroy
      purchase_cart.remove_item(
        item_id: params[:item_id]
      )

      persist_purchase_cart!

      redirect_to purchase_path,
                  notice:
                    "Purchase item was removed."
    end

    private

    def purchase_path
      new_purchasing_purchase_path(
        branch_id: @purchase_branch.id
      )
    end

    def cart_item_params
      params
        .require(:purchase_cart_item)
        .permit(
          :item_id,
          :quantity,
          :unit_cost,
          :discount_amount
        )
    end
  end
end
