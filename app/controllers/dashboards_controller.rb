class DashboardsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_organization!

  def show
    @organization = current_organization
    @membership = current_membership
    @branch = current_branch

    @branches_count = @organization.branches.active.count
    @users_count = @organization.memberships.active.count
  end
end