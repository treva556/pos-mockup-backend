class InventoryAdjustmentsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_organization!
  before_action :require_inventory_adjustment_management!
  before_action :load_form_options

  def new
    @adjustment =
      InventoryAdjustmentForm.new(
        branch_id:
          params[:branch_id] || current_branch_id,
        item_id: params[:item_id],
        movement_type: "opening",
        occurred_at: Time.current
      )
  end

  def create
    @adjustment =
      InventoryAdjustmentForm.new(
        inventory_adjustment_params
      )

    if @adjustment.invalid?
      render :new,
             status: :unprocessable_entity

      return
    end

    branch = @branches.find(@adjustment.branch_id)
    item = @items.find(@adjustment.item_id)

    movement =
      Inventory::PostMovement.call(
        organization: current_organization,
        branch: branch,
        item: item,
        recorded_by: current_user,
        movement_type: @adjustment.movement_type,
        quantity_change: @adjustment.signed_quantity,
        occurred_at: @adjustment.occurred_at,
        reference: @adjustment.reference,
        notes: @adjustment.notes
      )

    redirect_to new_inventory_adjustment_path(
      branch_id: branch.id,
      item_id: item.id
    ),
                notice:
                  "#{movement.quantity} #{item.unit_of_measure.symbol} " \
                  "was recorded for #{item.name}."
  rescue ActiveRecord::RecordInvalid => error
    @adjustment.errors.add(
      :base,
      error.record.errors.full_messages.to_sentence
    )

    render :new,
           status: :unprocessable_entity
  rescue Inventory::InsufficientStockError,
         Inventory::InvalidOpeningStockError => error
    @adjustment.errors.add(:base, error.message)

    render :new,
           status: :unprocessable_entity
  end

  private

  def load_form_options
    @branches =
      current_organization
        .branches
        .where(active: true)
        .order(:name)

    @items =
      current_organization
        .items
        .active
        .stock_tracked
        .where(
          item_type: "product",
          tracks_expiry: false
        )
        .includes(:unit_of_measure)
        .alphabetical
  end

  def current_branch_id
    current_membership&.branch_id ||
      current_organization.main_branch&.id
  end

  def inventory_adjustment_params
    params.require(:inventory_adjustment).permit(
      :branch_id,
      :item_id,
      :movement_type,
      :quantity,
      :occurred_at,
      :reference,
      :notes
    )
  end
end
