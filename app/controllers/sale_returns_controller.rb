class SaleReturnsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_organization!

  before_action :require_sales_return_management!,
                only: %i[new create]

  before_action :require_sales_return_view!,
                only: %i[show return_note]

  before_action :set_sale,
                only: %i[new create]

  before_action :set_sale_return,
                only: %i[show return_note]

  def new
    load_return_form
  end

  def create
    sale_return =
      Sales::CompleteReturn.call(
        organization: current_organization,
        sale: @sale,
        recorded_by: current_user,
        reason_code:
          sale_return_params[:reason_code],
        reason_details:
          sale_return_params[:reason_details],
        notes:
          sale_return_params[:notes],
        returned_at:
          sale_return_params[:returned_at],
        lines:
          selected_lines
      )

    redirect_to sale_return_path(sale_return),
                notice:
                  "Sales return #{sale_return.return_number} " \
                  "was completed."
  rescue Sales::ReturnError => error
    @error_message = error.message

    load_return_form

    render :new,
           status: :unprocessable_entity
  end

  def show
  end

  def return_note
    render layout: false
  end

  private

  def set_sale
    @sale =
      visible_sales
        .completed
        .includes(
          :branch,
          :customer,
          :cashier,
          sale_lines: [
            :item,
            :tax_rate
          ]
        )
        .find(params[:sale_id])
  end

  def set_sale_return
    @sale_return =
      visible_sale_returns
        .includes(
          :branch,
          :recorded_by,
          sale: [
            :customer,
            :cashier
          ],
          sale_return_lines: [
            :item,
            :inventory_batch
          ],
          customer_refunds: [
            :payment_method,
            :money_account,
            :recorded_by
          ]
        )
        .find(params[:id])

    @sale =
      @sale_return.sale
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

  def visible_sale_returns
    scope =
      current_organization.sale_returns

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

  def load_return_form
    @returnable_lines =
      @sale
        .sale_lines
        .ordered
        .select do |line|
          line.returnable_quantity.positive?
        end

    @batch_options_by_line =
      @returnable_lines.index_with do |line|
        batches_for(line)
      end

    @reason_options =
      SaleReturn.reason_codes.keys.map do |reason|
        [
          reason.titleize,
          reason
        ]
      end

    @disposition_options =
      [
        [ "Restock as sellable", "restock" ],
        [ "Quarantine", "quarantine" ],
        [ "Damaged — do not restock", "damaged" ],
        [ "Expired — do not restock", "expired" ],
        [ "Not applicable", "not_applicable" ]
      ]
  end

  def batches_for(line)
    return [] unless line.item.tracks_expiry?

    batch_ids =
      @sale
        .stock_movements
        .where(
          movement_type: "sale",
          item_id: line.item_id
        )
        .where.not(
          inventory_batch_id: nil
        )
        .distinct
        .pluck(:inventory_batch_id)

    current_organization
      .inventory_batches
      .where(id: batch_ids)
      .order(
        :expires_on,
        :received_at
      )
  end

  def sale_return_params
    params
      .require(:sale_return)
      .permit(
        :reason_code,
        :reason_details,
        :notes,
        :returned_at
      )
  end

  def selected_lines
    raw_lines =
      params
        .require(:sale_return)
        .fetch(:lines, {})

    raw_lines
      .values
      .map do |line|
        line.permit(
          :selected,
          :sale_line_id,
          :quantity,
          :stock_disposition,
          :inventory_batch_id,
          :reason_code,
          :notes
        ).to_h
      end
      .select do |line|
        line["selected"] == "1"
      end
  end
end
