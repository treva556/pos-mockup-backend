class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  before_action :enforce_password_change!
  helper_method :current_user,
                :current_membership,
                :current_organization,
                :current_branch,
                :signed_in?,
                :branch_switching_allowed?

  private

  def current_user
    return @current_user if defined?(@current_user)

    @current_user =
      User.active.find_by(id: session[:user_id])
  end

  def signed_in?
    current_user.present?
  end

  def current_membership
    return @current_membership if defined?(@current_membership)
    return @current_membership = nil unless current_user

    memberships =
      current_user
        .memberships
        .active
        .includes(:organization, :branch)
        .joins(:organization)
        .merge(Organization.active)

    @current_membership =
      if session[:organization_id].present?
        memberships.find_by(
          organization_id: session[:organization_id]
        )
      else
        memberships.order(:created_at).first
      end
  end

  def current_organization
    current_membership&.organization
  end

  def current_branch
  return @current_branch if defined?(@current_branch)

  unless current_organization
    return @current_branch = nil
  end

  # A branch-restricted employee must always use their
  # assigned branch.
  if current_membership&.branch_id.present?
    return @current_branch = current_membership.branch
  end

  # Organization-wide users may select a branch.
  if session[:branch_id].present?
    @current_branch =
      current_organization
        .branches
        .active
        .find_by(id: session[:branch_id])
  end

  @current_branch ||=
    current_organization.main_branch ||
    current_organization.branches.active.order(:name).first
end

 def branch_switching_allowed?
  current_membership.present? &&
    current_membership.branch_id.nil?
  end

  def require_organization_admin!
  return if current_membership&.organization_admin?

  redirect_to dashboard_path,
              alert: "Only organization owners and admins can do that."
  end

  def authenticate_user!
    return if signed_in?

    if request.get? || request.head?
      session[:return_to] = request.fullpath
    end

    redirect_to login_path,
                alert: "Please log in to continue."
  end

  def require_organization!
    return if current_organization.present?

    redirect_to new_onboarding_organization_path,
                alert: "Create your organization first."
  end

  def redirect_authenticated_user
    return unless signed_in?

    redirect_to after_login_path
  end

  def enforce_password_change!
  return unless signed_in?
  return unless current_user.must_change_password?

  return if controller_path == "account/passwords"

  if controller_path == "sessions" &&
     action_name == "destroy"
    return
  end

  redirect_to edit_account_password_path,
              alert:
                "Change your temporary password to continue."
  end

  def after_login_path
    if current_user&.must_change_password?
      return edit_account_password_path
    end

    if current_user.memberships.active.exists?
      dashboard_path
    else
      new_onboarding_organization_path
    end
    end

    def require_money_setup_management!
    return if current_membership&.money_setup_management?

    redirect_to dashboard_path,
                alert:
                  "Your role cannot manage payment and money setup."
  end

  def require_inventory_adjustment_management!
    return if current_membership&.inventory_adjustment_management?

    redirect_to dashboard_path,
                alert: "Your role cannot adjust inventory."
  end

  def require_inventory_view!
    return if current_membership&.inventory_view?

    redirect_to dashboard_path,
                alert: "Your role cannot view inventory."
  end

  def require_pos_access!
    return if current_membership&.pos_access?

    redirect_to dashboard_path,
                alert: "Your role cannot operate the POS."
  end
end
