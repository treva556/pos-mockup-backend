module Pos
  class SalesController < BaseController
    def new
      @query = params[:q].to_s.strip

      @items =
        current_organization
          .items
          .active
          .includes(
            :unit_of_measure,
            :tax_rate
          )
          .alphabetical

      filter_items_by_query
      limit_items

      @customers =
        current_organization
          .customers
          .where(active: true)
          .order(:name)

      @cart = pos_cart
      @calculation = @cart.calculation

      load_stock_quantities
    rescue Sales::InvalidLineError => error
      clear_pos_cart!

      redirect_to pos_sale_path,
                  alert:
                    "#{error.message}. The cart was cleared."
    end

   def create
        sale =
            Sales::CompleteSale.call(
            organization: current_organization,
            branch: @pos_branch,
            cashier: current_user,
            cart: pos_cart,
            payment_plan: pos_payment_plan,
            sold_at: Time.current,
            due_on: completion_params[:due_on],
            notes: completion_params[:notes]
            )

        clear_pos_cart!

        redirect_to sale_path(sale),
                    notice:
                        "Sale #{sale.sale_number} was completed."
        rescue Sales::CompletionError,
            Sales::InvalidLineError,
            Sales::InvalidPaymentError,
            Inventory::InsufficientStockError => error
        redirect_to pos_checkout_path(
            branch_id: @pos_branch.id
        ),
                    alert: error.message
        rescue ActiveRecord::RecordInvalid => error
        redirect_to pos_checkout_path(
            branch_id: @pos_branch.id
        ),
                    alert:
                        error.record
                        .errors
                        .full_messages
                        .to_sentence
    end

    private

    def filter_items_by_query
      return if @query.blank?

      pattern =
        "%#{ActiveRecord::Base
          .sanitize_sql_like(@query)}%"

      @items =
        @items.where(
          <<~SQL.squish,
            items.name ILIKE :pattern OR
            items.sku ILIKE :pattern OR
            items.barcode ILIKE :pattern
          SQL
          pattern: pattern
        )
    end

    def limit_items
      @items = @items.limit(50)
    end

    def completion_params
        params
            .require(:sale)
            .permit(
            :due_on,
            :notes
            )
    end

    def load_stock_quantities
      stock_item_ids =
        @items.select(&:stockable?).map(&:id)

      @stock_quantities =
        current_organization
          .stock_levels
          .where(
            branch: @pos_branch,
            item_id: stock_item_ids
          )
          .pluck(
            :item_id,
            :quantity_on_hand
          )
          .to_h
    end
  end
end
