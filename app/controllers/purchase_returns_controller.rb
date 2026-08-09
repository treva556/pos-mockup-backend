class PurchaseReturnsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_organization!

  before_action :require_purchase_return_management!,
                only: %i[new create]

  before_action :require_purchase_return_view!,
                only: %i[show return_note]

  before_action :set_purchase,
                only: %i[new create]

  before_action :set_purchase_return,
                only: %i[show return_note]

  def new
    load_return_form
  end

  def create
    purchase_return =
      Purchases::CompleteReturn.call(
        organization: current_organization,
        purchase: @purchase,
        recorded_by: current_user,
        reason_code:
          purchase_return_params[:reason_code],
        supplier_document_number:
          purchase_return_params[
            :supplier_document_number
          ],
        reason_details:
          purchase_return_params[:reason_details],
        notes:
          purchase_return_params[:notes],
        returned_at:
          purchase_return_params[:returned_at],
        lines:
          selected_lines
      )

    redirect_to purchase_return_path(
      purchase_return
    ),
                notice:
                  "Purchase return " \
                  "#{purchase_return.return_number} " \
                  "was completed."
  rescue Purchases::ReturnError => error
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

  def set_purchase
    @purchase =
      visible_purchases
        .received
        .includes(
          :branch,
          :supplier,
          purchase_lines: [
            :inventory_batch,
            {
              item: :unit_of_measure
            }
          ]
        )
        .find(params[:purchase_id])
  end

  def set_purchase_return
    @purchase_return =
      visible_purchase_returns
        .includes(
          :branch,
          :recorded_by,
          purchase: [
            :supplier,
            :branch
          ],
          purchase_return_lines: [
            :item,
            :inventory_batch
          ],
          supplier_credits: [
            :recorded_by
          ]
        )
        .find(params[:id])

    @purchase =
      @purchase_return.purchase
  end

  def visible_purchases
    scope =
      current_organization.purchases

    return scope if
      current_membership.branch_id.blank?

    scope.where(
      branch_id:
        current_membership.branch_id
    )
  end

  def visible_purchase_returns
    scope =
      current_organization.purchase_returns

    return scope if
      current_membership.branch_id.blank?

    scope.where(
      branch_id:
        current_membership.branch_id
    )
  end

  def load_return_form
    @returnable_lines =
      @purchase
        .purchase_lines
        .ordered
        .select do |line|
          line.returnable_quantity.positive?
        end

    @reason_options =
      PurchaseReturn
        .reason_codes
        .keys
        .map do |reason|
          [
            reason.titleize,
            reason
          ]
        end
  end

  def purchase_return_params
    params
      .require(:purchase_return)
      .permit(
        :reason_code,
        :supplier_document_number,
        :reason_details,
        :notes,
        :returned_at
      )
  end

  def selected_lines
    raw_lines =
      params
        .require(:purchase_return)
        .fetch(:lines, {})

    raw_lines
      .values
      .map do |line|
        line.permit(
          :selected,
          :purchase_line_id,
          :quantity,
          :reason_code,
          :notes
        ).to_h
      end
      .select do |line|
        line["selected"] == "1"
      end
  end
end
