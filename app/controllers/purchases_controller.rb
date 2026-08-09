class PurchasesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_organization!
  before_action :require_supplier_account_view!

  before_action :set_purchase,
                only: %i[show receipt]

  def index
    @query = params[:q].to_s.strip

    @status =
      params[:status].presence_in(
        %w[
          all
          outstanding
          unpaid
          partially_paid
          paid
          overdue
        ]
      ) || "all"

    @branch_id =
      selected_branch_id

    @supplier_id =
      selected_supplier_id

    @date_from =
      cast_date(params[:date_from])

    @date_to =
      cast_date(params[:date_to])

    @branches =
      available_branches.order(:name)

    @suppliers =
      current_organization
        .suppliers
        .order(:name)

    scope =
      filtered_purchases

    @purchase_count =
      scope.reorder(nil).count

    @purchase_total =
      scope.reorder(nil).sum(:total).to_d

    @amount_paid_total =
      scope.reorder(nil).sum(:amount_paid).to_d

    @balance_due_total =
      scope
        .reorder(nil)
        .includes(:purchase_returns)
        .sum do |purchase|
          purchase.effective_balance_due
        end

    @purchases =
      scope
        .includes(
          :branch,
          :supplier,
          :recorded_by,
          :purchase_returns
        )
        .recent_first
        .limit(500)
  end

  def show
  end

  def receipt
    render layout: false
  end

  private

  def set_purchase
    @purchase =
      visible_purchases
        .includes(
          :branch,
          :supplier,
          :recorded_by,
          purchase_payments: [
            :payment_method,
            :money_account,
            :recorded_by
          ],
          purchase_lines: [
            :item,
            :tax_rate,
            :inventory_batch
          ],
          purchase_returns: [
            :recorded_by,
            {
              purchase_return_lines: [
                :item,
                :inventory_batch
              ]
            },
            {
              supplier_credits:
                :recorded_by
            }
          ]
        )
        .find(params[:id])
  end

  def visible_purchases
    scope =
      current_organization
        .purchases

    return scope if
      current_membership.branch_id.blank?

    scope.where(
      branch_id:
        current_membership.branch_id
    )
  end

  def filtered_purchases
    scope =
      visible_purchases
        .received
        .joins(:supplier)

    if @branch_id.present?
      scope =
        scope.where(
          branch_id: @branch_id
        )
    end

    if @supplier_id.present?
      scope =
        scope.where(
          supplier_id: @supplier_id
        )
    end

    if @query.present?
      pattern =
        "%#{ActiveRecord::Base
          .sanitize_sql_like(@query)}%"

      scope =
        scope.where(
          <<~SQL.squish,
            purchases.purchase_number ILIKE :pattern OR
            purchases.supplier_invoice_number ILIKE :pattern OR
            suppliers.name ILIKE :pattern
          SQL
          pattern: pattern
        )
    end

    if @date_from.present?
      scope =
        scope.where(
          "purchases.purchased_on >= ?",
          @date_from
        )
    end

    if @date_to.present?
      scope =
        scope.where(
          "purchases.purchased_on <= ?",
          @date_to
        )
    end

    apply_status_filter(scope)
  end

  def apply_status_filter(scope)
    case @status
    when "outstanding"
      scope.where(
        "#{effective_balance_sql} > 0"
      )
    when "unpaid"
      scope.where(
        payment_status: "unpaid"
      )
    when "partially_paid"
      scope.where(
        payment_status: "partially_paid"
      )
    when "paid"
      scope.where(
        payment_status: "paid"
      )
    when "overdue"
      scope
        .where(
          "#{effective_balance_sql} > 0"
        )
        .where(
          "purchases.due_on < ?",
          Date.current
        )
    else
      scope
    end
  end

  def effective_balance_sql
    <<~SQL.squish
      GREATEST(
        purchases.balance_due -
        COALESCE(
          (
            SELECT SUM(purchase_returns.total)
            FROM purchase_returns
            WHERE purchase_returns.purchase_id =
                  purchases.id
              AND purchase_returns.status = 'completed'
          ),
          0
        ),
        0
      )
    SQL
  end

  def available_branches
    scope =
      current_organization
        .branches
        .where(active: true)

    return scope if
      current_membership.branch_id.blank?

    scope.where(
      id:
        current_membership.branch_id
    )
  end

  def selected_branch_id
    return current_membership.branch_id if
      current_membership.branch_id.present?

    return if params[:branch_id].blank?

    available_branches
      .find(params[:branch_id])
      .id
  end

  def selected_supplier_id
    return if params[:supplier_id].blank?

    current_organization
      .suppliers
      .find(params[:supplier_id])
      .id
  end

  def cast_date(value)
    return if value.blank?

    ActiveModel::Type::Date
      .new
      .cast(value)
  end
end
