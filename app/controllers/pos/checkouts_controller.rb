module Pos
  class CheckoutsController < BaseController
    before_action :require_nonempty_cart

    def show
      @cart = pos_cart
      @calculation = @cart.calculation
      @payment_plan = pos_payment_plan

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
    rescue Sales::InvalidLineError,
           Sales::InvalidPaymentError => error
      clear_pos_payment_plan!

      redirect_to pos_sale_path,
                  alert: error.message
    end

    private

    def require_nonempty_cart
      return unless pos_cart.empty?

      redirect_to pos_sale_path,
                  alert:
                    "Add at least one item before continuing."
    end
  end
end
