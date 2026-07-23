class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  helper_method :current_user,
                :current_membership,
                :current_organization,
                :current_branch,
                :signed_in?

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
    current_membership&.branch ||
      current_organization&.main_branch
  end

  def authenticate_user!
    return if signed_in?

    session[:return_to] = request.fullpath if request.get?

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

  def after_login_path
    if current_user.memberships.active.exists?
      dashboard_path
    else
      new_onboarding_organization_path
    end
  end
end