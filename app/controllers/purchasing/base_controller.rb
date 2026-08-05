module Purchasing
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :require_organization!
    before_action :require_supplier_management!
    before_action :set_purchase_branch

    helper_method :purchase_cart

    private

    def set_purchase_branch
      branches =
        current_organization
          .branches
          .where(active: true)

      @purchase_branch =
        if current_membership.branch_id.present?
          branches.find(
            current_membership.branch_id
          )
        elsif params[:branch_id].present?
          branches.find(
            params[:branch_id]
          )
        else
          current_organization.main_branch ||
            branches.first!
        end
    end

    def purchase_cart
      @purchase_cart ||=
        Purchases::Cart.new(
          organization: current_organization,
          branch: @purchase_branch,
          data:
            session[purchase_cart_session_key]
        )
    end

    def persist_purchase_cart!
      session[purchase_cart_session_key] =
        purchase_cart.to_session
    end

    def clear_purchase_cart!
      session.delete(
        purchase_cart_session_key
      )

      @purchase_cart = nil
    end

    def purchase_cart_session_key
      "purchase_cart:" \
        "#{current_organization.id}:" \
        "#{@purchase_branch.id}"
    end
  end
end
