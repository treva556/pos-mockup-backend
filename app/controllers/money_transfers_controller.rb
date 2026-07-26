class MoneyTransfersController < ApplicationController
  before_action :authenticate_user!
  before_action :require_organization!
  before_action :require_money_setup_management!

  before_action :set_money_transfer,
                only: :show

  before_action :load_form_options,
                only: %i[new create]

  def index
    @query = params[:q].to_s.strip
    @account_id = params[:account_id].presence

    @accounts =
      current_organization
        .money_accounts
        .alphabetical

    @money_transfers =
      current_organization
        .money_transfers
        .includes(
          :from_money_account,
          :to_money_account,
          :recorded_by
        )
        .recent_first

    filter_by_account
    filter_by_query
  end

  def show
  end

  def new
    @money_transfer =
      current_organization.money_transfers.new(
        transferred_at: Time.current
      )
  end

  def create
    @money_transfer =
      current_organization
        .money_transfers
        .new(transfer_attributes)

    @money_transfer.recorded_by = current_user

    @money_transfer.from_money_account =
      selected_from_account

    @money_transfer.to_money_account =
      selected_to_account

    if @money_transfer.save
      redirect_to @money_transfer,
                  notice:
                    "Money transfer was recorded."
    else
      render :new,
             status: :unprocessable_entity
    end
  end

  private

  def set_money_transfer
    @money_transfer =
      current_organization
        .money_transfers
        .includes(
          :from_money_account,
          :to_money_account,
          :recorded_by
        )
        .find(params[:id])
  end

  def load_form_options
    @from_accounts =
      current_organization
        .money_accounts
        .active
        .payable
        .includes(:branch)
        .alphabetical

    @to_accounts =
      current_organization
        .money_accounts
        .active
        .receivable
        .includes(:branch)
        .alphabetical
  end

  def selected_from_account
    account_id =
      money_transfer_params[
        :from_money_account_id
      ]

    return if account_id.blank?

    @from_accounts.find(account_id)
  end

  def selected_to_account
    account_id =
      money_transfer_params[
        :to_money_account_id
      ]

    return if account_id.blank?

    @to_accounts.find(account_id)
  end

  def transfer_attributes
    money_transfer_params.except(
      :from_money_account_id,
      :to_money_account_id
    )
  end

  def money_transfer_params
    params.require(:money_transfer).permit(
      :from_money_account_id,
      :to_money_account_id,
      :amount,
      :transferred_at,
      :reference,
      :notes
    )
  end

  def filter_by_account
    return if @account_id.blank?

    account = @accounts.find(@account_id)

    base_scope = @money_transfers

    @money_transfers =
      base_scope
        .where(
          from_money_account_id: account.id
        )
        .or(
          base_scope.where(
            to_money_account_id: account.id
          )
        )
  end

  def filter_by_query
    return if @query.blank?

    pattern =
      "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"

    @money_transfers =
      @money_transfers.where(
        <<~SQL.squish,
          money_transfers.reference ILIKE :pattern OR
          money_transfers.notes ILIKE :pattern
        SQL
        pattern: pattern
      )
  end
end
