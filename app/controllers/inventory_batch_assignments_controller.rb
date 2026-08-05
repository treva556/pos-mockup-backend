class InventoryBatchAssignmentsController <
  ApplicationController
  before_action :authenticate_user!
  before_action :require_organization!
  before_action :require_inventory_adjustment_management!

  def new
    load_form_options
  end

  def create
    branch =
      available_branches.find(
        assignment_params[:branch_id]
      )

    item =
      current_organization
        .items
        .active
        .stock_tracked
        .find(
          assignment_params[:item_id]
        )

    batch =
      Inventory::AssignExistingStockBatch.call(
        organization: current_organization,
        branch: branch,
        item: item,
        batch_number:
          assignment_params[:batch_number],
        manufactured_on:
          assignment_params[:manufactured_on],
        expires_on:
          assignment_params[:expires_on],
        unit_cost:
          assignment_params[:unit_cost],
        received_at: Time.current
      )

    redirect_to inventory_batches_path,
                notice:
                  "Existing stock for #{item.name} was assigned " \
                  "to batch #{batch.batch_number || batch.id}."
  rescue ActiveRecord::RecordNotFound
    redirect_to new_inventory_batch_assignment_path,
                alert:
                  "The selected branch or product is unavailable."
  rescue Inventory::BatchAssignmentError,
         ActiveRecord::RecordInvalid => error
    load_form_options

    flash.now[:alert] =
      if error.respond_to?(:record)
        error.record.errors.full_messages.to_sentence
      else
        error.message
      end

    render :new,
           status: :unprocessable_entity
  end

  private

  def load_form_options
    @branches =
      available_branches.order(:name)

    @items =
      current_organization
        .items
        .active
        .stock_tracked
        .where(
          item_type: "product",
          tracks_expiry: true
        )
        .alphabetical
  end

  def available_branches
    scope =
      current_organization
        .branches
        .where(active: true)

    return scope if current_membership.branch_id.blank?

    scope.where(
      id: current_membership.branch_id
    )
  end

  def assignment_params
    params
      .require(:inventory_batch_assignment)
      .permit(
        :branch_id,
        :item_id,
        :batch_number,
        :manufactured_on,
        :expires_on,
        :unit_cost
      )
  end
end
