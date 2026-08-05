class InventoryBatchesController <
  ApplicationController
  before_action :authenticate_user!
  before_action :require_organization!
  before_action :require_inventory_view!

  def index
    @status =
      params[:status].presence ||
      "30"

    @branch_id =
      permitted_branch_id

    @branches =
      available_branches

    @batches =
      filtered_batches
        .includes(
          :branch,
          :item,
          purchase_line: {
            purchase: :supplier
          }
        )
        .order(
          expires_on: :asc,
          received_at: :asc
        )
        .limit(500)
  end

  private

  def base_scope
    scope =
      current_organization
        .inventory_batches
        .with_quantity

    if current_membership.branch_id.present?
      scope.where(
        branch_id:
          current_membership.branch_id
      )
    elsif @branch_id.present?
      scope.where(
        branch_id: @branch_id
      )
    else
      scope
    end
  end

  def filtered_batches
    case @status
    when "expired"
      base_scope.where(
        "expires_on < ?",
        Date.current
      )
    when "7"
      expiring_within(7)
    when "30"
      expiring_within(30)
    when "90"
      expiring_within(90)
    else
      base_scope
    end
  end

  def expiring_within(days)
    base_scope.where(
      expires_on:
        Date.current..
          days.days.from_now.to_date
    )
  end

  def permitted_branch_id
    return current_membership.branch_id if
      current_membership.branch_id.present?

    return if params[:branch_id].blank?

    current_organization
      .branches
      .find(params[:branch_id])
      .id
  end

  def available_branches
    return Branch.none if
      current_membership.branch_id.present?

    current_organization
      .branches
      .where(active: true)
      .order(:name)
  end
end
