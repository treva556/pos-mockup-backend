module Purchasing
  class PurchasesController < BaseController
    def new
      @query = params[:q].to_s.strip

      @items =
        current_organization
          .items
          .where(active: true)
          .includes(
            :unit_of_measure,
            :tax_rate
          )
          .order(:name)

      filter_items
      limit_and_select_stock_items

      @suppliers =
        current_organization
          .suppliers
          .where(active: true)
          .order(:name)

      @cart = purchase_cart
      @calculation = @cart.calculation
    rescue Purchases::InvalidLineError,
           Purchases::ReceivingError => error
      clear_purchase_cart!

      redirect_to new_purchasing_purchase_path(
        branch_id: @purchase_branch.id
      ),
                  alert:
                    "#{error.message}. The purchase cart was cleared."
    end

    def create
      purchase =
        Purchases::ReceivePurchase.call(
          organization: current_organization,
          branch: @purchase_branch,
          recorded_by: current_user,
          cart: purchase_cart,
          received_at: Time.current
        )

      clear_purchase_cart!

      redirect_to purchase_path(purchase),
                  notice:
                    "Purchase #{purchase.purchase_number} " \
                    "was received."
    rescue Purchases::ReceivingError,
           Purchases::InvalidLineError,
           Inventory::InsufficientStockError => error
      redirect_to new_purchasing_purchase_path(
        branch_id: @purchase_branch.id
      ),
                  alert: error.message
    rescue ActiveRecord::RecordNotUnique
      redirect_to new_purchasing_purchase_path(
        branch_id: @purchase_branch.id
      ),
                  alert:
                    "That supplier invoice number has already " \
                    "been recorded."
    rescue ActiveRecord::RecordInvalid => error
      redirect_to new_purchasing_purchase_path(
        branch_id: @purchase_branch.id
      ),
                  alert:
                    error.record
                      .errors
                      .full_messages
                      .to_sentence
    end

    private

    def filter_items
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

    def limit_and_select_stock_items
      @items =
        @items
          .limit(100)
          .to_a
          .select(&:stockable?)
          .first(50)
    end
  end
end
