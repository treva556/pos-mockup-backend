class StockTransfersController < ApplicationController
  before_action :authenticate_user!
  before_action :require_organization!
  before_action :require_inventory_adjustment_management!

  before_action :set_stock_transfer,
                only: :show

  before_action :load_form_options,
                only: %i[new create]

  def index
    @stock_transfers =
      current_organization
        .stock_transfers
        .includes(
          :from_branch,
          :to_branch,
          :item,
          :recorded_by
        )
        .recent_first
  end

  def show
  end

  def new
    @stock_transfer =
      current_organization.stock_transfers.new(
        transferred_at: Time.current
      )
  end

  def create
    build_stock_transfer

    if @stock_transfer.invalid?
      render :new,
             status: :unprocessable_entity

      return
    end

    @stock_transfer =
      Inventory::TransferStock.call(
        organization: current_organization,
        from_branch: @stock_transfer.from_branch,
        to_branch: @stock_transfer.to_branch,
        item: @stock_transfer.item,
        recorded_by: current_user,
        quantity: @stock_transfer.quantity,
        transferred_at: @stock_transfer.transferred_at,
        reference: @stock_transfer.reference,
        notes: @stock_transfer.notes
      )

    redirect_to @stock_transfer,
                notice: "Stock transfer was completed."
  rescue ActiveRecord::RecordInvalid => error
    @stock_transfer.errors.add(
      :base,
      error.record.errors.full_messages.to_sentence
    )

    render :new,
           status: :unprocessable_entity
  rescue Inventory::InsufficientStockError => error
    @stock_transfer.errors.add(:base, error.message)

    render :new,
           status: :unprocessable_entity
  end

  private

  def set_stock_transfer
    @stock_transfer =
      current_organization
        .stock_transfers
        .includes(
          :from_branch,
          :to_branch,
          :item,
          :recorded_by,
          :stock_movements
        )
        .find(params[:id])
  end

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
        .where(item_type: "product")
        .includes(:unit_of_measure)
        .alphabetical
  end

  def build_stock_transfer
    attributes =
      stock_transfer_params.except(
        :from_branch_id,
        :to_branch_id,
        :item_id
      )

    @stock_transfer =
      current_organization
        .stock_transfers
        .new(attributes)

    @stock_transfer.from_branch =
      selected_branch(:from_branch_id)

    @stock_transfer.to_branch =
      selected_branch(:to_branch_id)

    @stock_transfer.item = selected_item
    @stock_transfer.recorded_by = current_user
  end

  def selected_branch(attribute)
    id = stock_transfer_params[attribute]
    return if id.blank?

    @branches.find(id)
  end

  def selected_item
    id = stock_transfer_params[:item_id]
    return if id.blank?

    @items.find(id)
  end

  def stock_transfer_params
    params.require(:stock_transfer).permit(
      :from_branch_id,
      :to_branch_id,
      :item_id,
      :quantity,
      :transferred_at,
      :reference,
      :notes
    )
  end
end
