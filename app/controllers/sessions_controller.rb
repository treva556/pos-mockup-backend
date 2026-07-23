class SessionsController < ApplicationController
  before_action :redirect_authenticated_user,
                only: %i[new create]

  def new
  end

  def create
    email = params[:email].to_s.strip.downcase
    user = User.find_by(email: email)

    if user&.active? && user.authenticate(params[:password])
      return_to = session[:return_to]

      reset_session

      session[:user_id] = user.id

      membership =
        user.memberships
            .active
            .includes(:organization, :branch)
            .joins(:organization)
            .merge(Organization.active)
            .order(:created_at)
            .first

      session[:organization_id] = membership&.organization_id

      @current_user = user
      @current_membership = membership

      destination =
        return_to.presence ||
        if membership.present?
          dashboard_path
        else
          new_onboarding_organization_path
        end

      redirect_to destination,
                  notice: "Welcome back, #{user.name}."
    else
      flash.now[:alert] = "Invalid email or password."

      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session

    redirect_to login_path,
                notice: "You have been logged out."
  end
end