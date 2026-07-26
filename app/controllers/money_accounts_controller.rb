class MoneyAccountsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_organization!
  before_action :require_money_setup_management!

  before_action :set_money_account,
                only: %i[
                  show
                  edit
                  update
                  toggle_status
                ]

  def index
    @query = params[:q].to_s.strip

    @status =
      params[:status].presence_in(
        %w[active inactive all]
      ) || "active"

    @account_type =
      params[:account_type].presence_in(
        MoneyAccount.account_types.keys + [ "all" ]
      ) || "all"

    @money_accounts =
      current_organization
        .money_accounts
        .includes(:branch)
        .alphabetical

    @money_accounts =
      case @status
      when "inactive"
        @money_accounts.where(active: false)
      when "all"
        @money_accounts
      else
        @money_accounts.active
      end

    unless @account_type == "all"
      @money_accounts =
        @money_accounts.where(
          account_type: @account_type
        )
    end

    return if @query.blank?

    pattern =
      "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"

    @money_accounts =
      @money_accounts.where(
        <<~SQL.squish,
          money_accounts.name ILIKE :pattern OR
          money_accounts.account_number ILIKE :pattern
        SQL
        pattern: pattern
      )
  end

  def show
  end

  def new
    @money_account =
      current_organization.money_accounts.new(
        account_type: "cash",
        opening_balance: 0,
        can_receive: true,
        can_pay: true,
        active: true
      )

    load_form_options
  end

  def create
    @money_account =
      current_organization
        .money_accounts
        .new(money_account_params)

    if @money_account.save
      redirect_to @money_account,
                  notice:
                    "#{@money_account.name} was created."
    else
      load_form_options

      render :new,
             status: :unprocessable_entity
    end
  end

  def edit
    load_form_options
  end

  def update
    if @money_account.update(money_account_params)
      redirect_to @money_account,
                  notice:
                    "#{@money_account.name} was updated."
    else
      load_form_options

      render :edit,
             status: :unprocessable_entity
    end
  end

  def toggle_status
    if disabling_used_account?
      redirect_to money_accounts_path,
                  alert:
                    "Remove this account from active branch payment defaults before disabling it."

      return
    end

    @money_account.update!(
      active: !@money_account.active?
    )

    status =
      @money_account.active? ? "enabled" : "disabled"

    redirect_to money_accounts_path,
                notice:
                  "#{@money_account.name} was #{status}."
  end

  private

  def set_money_account
    @money_account =
      current_organization
        .money_accounts
        .find(params[:id])
  end

  def load_form_options
    scope = current_organization.branches

    selected_id = @money_account&.branch_id

    @branches =
      scope
        .where(active: true)
        .or(scope.where(id: selected_id))
        .order(:name)
  end

  def disabling_used_account?
    @money_account.active? &&
      @money_account
        .branch_payment_settings
        .enabled
        .exists?
  end

  def money_account_params
    params.require(:money_account).permit(
      :name,
      :account_type,
      :account_number,
      :branch_id,
      :opening_balance,
      :opening_balance_date,
      :can_receive,
      :can_pay,
      :notes
    )
  end
end
