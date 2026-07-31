class SalesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_organization!
  before_action :require_pos_access!

  before_action :set_sale,
                only: %i[show receipt]

  def index
    load_filter_options
    load_filters

    scope =
      visible_sales
        .completed
        .includes(
          :branch,
          :customer,
          :cashier
        )
        .recent_first

    scope = filter_by_branch(scope)
    scope = filter_by_payment_status(scope)
    scope = filter_by_query(scope)
    scope = filter_by_dates(scope)

    @sales_total =
      scope.sum(:total)

    @payments_total =
      scope.sum(:amount_paid)

    @outstanding_total =
      scope.sum(:balance_due)

    @sales =
      scope.limit(200)
  end

  def show
  end

  def receipt
    render layout: false
  end

  private

  def set_sale
    @sale =
      visible_sales
        .includes(
          :branch,
          :customer,
          :cashier,
          sale_lines: [
            :item,
            :tax_rate
          ],
          sale_payments: [
            :payment_method,
            :money_account,
            :recorded_by
          ]
        )
        .find(params[:id])
  end

  def visible_sales
    scope =
      current_organization.sales

    if current_membership.cashier? &&
       current_membership.branch_id.present?
      scope =
        scope.where(
          branch_id:
            current_membership.branch_id
        )
    end

    scope
  end

  def load_filter_options
    @branches =
      current_organization
        .branches
        .where(active: true)
        .order(:name)

    if current_membership.cashier? &&
       current_membership.branch_id.present?
      @branches =
        @branches.where(
          id: current_membership.branch_id
        )
    end
  end

  def load_filters
    @query = params[:q].to_s.strip
    @branch_id = params[:branch_id].presence

    @payment_status =
      params[:payment_status].presence_in(
        Sale.payment_statuses.keys + [ "all" ]
      ) || "all"

    date_type =
      ActiveModel::Type::Date.new

    @date_from =
      date_type.cast(params[:date_from])

    @date_to =
      date_type.cast(params[:date_to])
  end

  def filter_by_branch(scope)
    return scope if @branch_id.blank?

    branch =
      @branches.find(@branch_id)

    scope.where(branch: branch)
  end

  def filter_by_payment_status(scope)
    return scope if @payment_status == "all"

    scope.where(
      payment_status: @payment_status
    )
  end

  def filter_by_query(scope)
    return scope if @query.blank?

    pattern =
      "%#{ActiveRecord::Base
        .sanitize_sql_like(@query)}%"

    scope
      .left_joins(:customer)
      .where(
        <<~SQL.squish,
          sales.sale_number ILIKE :pattern OR
          customers.name ILIKE :pattern
        SQL
        pattern: pattern
      )
  end

  def filter_by_dates(scope)
    if @date_from.present?
      scope =
        scope.where(
          "sales.sold_at >= ?",
          @date_from.beginning_of_day
        )
    end

    if @date_to.present?
      scope =
        scope.where(
          "sales.sold_at <= ?",
          @date_to.end_of_day
        )
    end

    scope
  end
end
