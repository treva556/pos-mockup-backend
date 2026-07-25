class TeamMembersController < ApplicationController
  before_action :authenticate_user!
  before_action :require_organization!
  before_action :require_organization_admin!

  before_action :set_membership,
                only: %i[edit update]

  before_action :protect_membership,
                only: %i[edit update]

  helper_method :assignable_role_options

  def index
    @memberships =
      current_organization
        .memberships
        .includes(:user, :branch)
        .order(active: :desc, created_at: :asc)
  end

  def new
    prepare_new_form
  end

  def create
    requested_role = team_member_params[:role]

    unless assignable_roles.include?(requested_role)
      prepare_new_form(
        values: team_member_params.to_h,
        errors: [ "You cannot assign that role." ]
      )

      render :new, status: :unprocessable_entity
      return
    end

    result =
      TeamMembers::Create.call(
        organization: current_organization,
        user_attributes: {
          name: team_member_params[:name],
          email: team_member_params[:email],
          password: team_member_params[:password],
          password_confirmation:
            team_member_params[:password_confirmation]
        },
        membership_attributes: {
          role: requested_role,
          branch_id: team_member_params[:branch_id]
        }
      )

    if result.success?
      redirect_to team_members_path,
                  notice:
                    "#{result.user.name} was added successfully."
    else
      prepare_new_form(
        values: team_member_params.to_h,
        errors: result.errors
      )

      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @branches = branches_for_form
  end

  def update
    requested_role = membership_params[:role]

    unless assignable_roles.include?(requested_role)
      @branches = branches_for_form
      @membership.errors.add(
        :role,
        "cannot be assigned by your account"
      )

      render :edit, status: :unprocessable_entity
      return
    end

    if @membership.update(membership_params)
      redirect_to team_members_path,
                  notice:
                    "#{@membership.user.name} was updated."
    else
      @branches = branches_for_form

      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_membership
    @membership =
      current_organization
        .memberships
        .includes(:user, :branch)
        .find(params[:id])
  end

  def protect_membership
    if @membership == current_membership
      redirect_to team_members_path,
                  alert: "You cannot change your own access."
      return
    end

    if @membership.owner?
      redirect_to team_members_path,
                  alert:
                    "The organization owner's access is protected."
      return
    end

    if current_membership.admin? && @membership.admin?
      redirect_to team_members_path,
                  alert:
                    "Administrators cannot manage another administrator."
    end
  end

  def assignable_roles
    if current_membership.owner?
      Membership::TEAM_ROLES
    else
      Membership::TEAM_ROLES - [ "admin" ]
    end
  end

  def assignable_role_options
    assignable_roles.map do |role|
      [ role.titleize, role ]
    end
  end

  def branches_for_form
    current_organization
      .branches
      .active
      .main_first
  end

  def prepare_new_form(values: {}, errors: [])
    @form_values = {
      "role" => "cashier",
      "branch_id" => current_branch&.id
    }.merge(values)

    @errors = errors
    @branches = branches_for_form
  end

  def team_member_params
    params.require(:team_member).permit(
      :name,
      :email,
      :password,
      :password_confirmation,
      :role,
      :branch_id
    )
  end

  def membership_params
    params.require(:membership).permit(
      :role,
      :branch_id,
      :active
    )
  end
end
