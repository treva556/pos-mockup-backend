class BranchesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_organization!

  before_action :require_organization_admin!,
                except: :select

  before_action :set_branch,
                only: %i[edit update select]

  def index
    @branches =
      current_organization
        .branches
        .main_first
  end

  def new
    @branch =
      current_organization.branches.new(
        active: true,
        main: false
      )
  end

  def create
    @branch =
      current_organization
        .branches
        .new(branch_params)

    @branch.main = false

    if @branch.save
      redirect_to branches_path,
                  notice: "#{@branch.name} was created."
    else
      render :new,
             status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @branch.update(branch_params)
      redirect_to branches_path,
                  notice: "#{@branch.name} was updated."
    else
      render :edit,
             status: :unprocessable_entity
    end
  end

  def select
    unless branch_switching_allowed?
      redirect_to dashboard_path,
                  alert: "You are assigned to a specific branch."
      return
    end

    unless @branch.active?
      redirect_to branches_path,
                  alert: "An inactive branch cannot be selected."
      return
    end

    session[:branch_id] = @branch.id

    redirect_back fallback_location: dashboard_path,
                  notice: "Current branch changed to #{@branch.name}."
  end

  private

  def set_branch
    @branch =
      current_organization
        .branches
        .find(params[:id])
  end

  def branch_params
    params.require(:branch).permit(
      :name,
      :code,
      :phone,
      :email,
      :address,
      :active
    )
  end
end
