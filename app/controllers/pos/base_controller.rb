module Pos
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :require_organization!
    before_action :require_pos_access!
    before_action :load_pos_branches
    before_action :set_pos_branch

    helper_method :pos_cart,
              :pos_payment_plan

    private

    def load_pos_branches
      scope =
        current_organization
          .branches
          .where(active: true)

      if current_membership.cashier? &&
         current_membership.branch_id.present?
        scope =
          scope.where(
            id: current_membership.branch_id
          )
      end

      @pos_branches = scope.order(:name)
    end

    def set_pos_branch
      requested_id =
        params[:branch_id].presence

      @pos_branch =
        if requested_id
          @pos_branches.find(requested_id)
        else
          preferred_pos_branch
        end

      raise ActiveRecord::RecordNotFound unless @pos_branch
    end

    def preferred_pos_branch
      @pos_branches.find_by(
        id: current_membership.branch_id
      ) ||
        @pos_branches.find_by(main: true) ||
        @pos_branches.first
    end

    def pos_cart
      @pos_cart ||=
        Sales::Cart.new(
          organization: current_organization,
          branch: @pos_branch,
          data: session[cart_session_key]
        )
    end

    def persist_pos_cart!
      session[cart_session_key] =
        pos_cart.to_session
    end

    def clear_pos_cart!
        session.delete(cart_session_key)
        session.delete(payment_plan_session_key)

        @pos_cart = nil
        @pos_payment_plan = nil
    end

    def cart_session_key
      "pos_cart:" \
        "#{current_organization.id}:" \
        "#{@pos_branch.id}"
    end

    def pos_payment_plan
  @pos_payment_plan ||=
    Sales::PaymentPlan.new(
      organization: current_organization,
      branch: @pos_branch,
      sale_total: pos_cart.calculation.total,
      data: session[payment_plan_session_key]
    )
    end

    def persist_pos_payment_plan!
    session[payment_plan_session_key] =
        pos_payment_plan.to_session
    end

    def clear_pos_payment_plan!
    session.delete(payment_plan_session_key)
    @pos_payment_plan = nil
    end

    def payment_plan_session_key
    "pos_payment_plan:" \
        "#{current_organization.id}:" \
        "#{@pos_branch.id}"
    end

    def pos_sale_path
      new_pos_sale_path(
        branch_id: @pos_branch.id
      )
    end
  end
end
