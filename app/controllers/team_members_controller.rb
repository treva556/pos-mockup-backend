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
      requested_role = submitted_team_role
      form_values = submitted_team_form_values

      unless assignable_roles.include?(requested_role)
        prepare_new_form(
          values: form_values,
          errors: [ "You cannot assign that role." ]
        )

        render :new, status: :unprocessable_entity
        return
      end

      result =
        TeamMembers::Create.call(
          organization: current_organization,
          user_attributes:
            team_member_identity_params.to_h.symbolize_keys,
          membership_attributes: {
            role: requested_role,
            branch_id: submitted_team_branch_id
          }
        )

      if result.success?
        redirect_to team_members_path,
                    notice:
                      "#{result.user.name} was added successfully."
      else
        prepare_new_form(
          values: form_values,
          errors: result.errors
        )

        render :new, status: :unprocessable_entity
      end
    end

  def edit
    @branches = branches_for_form
  end

  def update
      attributes = submitted_membership_attributes
      requested_role = attributes.fetch(:role)

      unless assignable_roles.include?(requested_role)
        @branches = branches_for_form

        @membership.errors.add(
          :role,
          "cannot be assigned by your account"
        )

        render :edit, status: :unprocessable_entity
        return
      end

      if @membership.update(attributes)
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

   def team_member_payload
      @team_member_payload ||=
        params.require(:team_member)
    end

    def membership_payload
      @membership_payload ||=
        params.require(:membership)
    end

    def team_member_identity_params
      team_member_payload.permit(
        :name,
        :email,
        :password,
        :password_confirmation
      )
    end

    def submitted_team_role
      team_member_payload[:role].to_s
    end

    def submitted_team_branch_id
      resolve_branch_id(team_member_payload[:branch_id])
    end

    def submitted_team_form_values
      {
        "name" => team_member_payload[:name],
        "email" => team_member_payload[:email],
        "role" => submitted_team_role,
        "branch_id" => submitted_team_branch_id
      }
    end

    def submitted_membership_attributes
      {
        role: membership_payload[:role].to_s,
        branch_id:
          resolve_branch_id(membership_payload[:branch_id]),
        active:
          ActiveModel::Type::Boolean.new.cast(
            membership_payload[:active]
          )
      }
    end

    def resolve_branch_id(raw_branch_id)
      return nil if raw_branch_id.blank?

      current_organization
        .branches
        .active
        .find(raw_branch_id)
        .id
    end
end
