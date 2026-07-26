class BranchPaymentSettingsController <
  ApplicationController
  before_action :authenticate_user!
  before_action :require_organization!
  before_action :require_money_setup_management!

  before_action :load_branches
  before_action :set_branch
  before_action :load_payment_methods
  before_action :load_money_accounts
  before_action :load_existing_settings

  def index
  end

  def update_defaults
    BranchPaymentSetting.transaction do
      @payment_methods.each do |payment_method|
        update_payment_setting!(payment_method)
      end
    end

    redirect_to branch_payment_settings_path(
      branch_id: @branch.id
    ),
                notice:
                  "Payment defaults for #{@branch.name} were updated."
  rescue ActiveRecord::RecordInvalid => error
    load_existing_settings

    flash.now[:alert] =
      error.record.errors.full_messages.to_sentence

    render :index,
           status: :unprocessable_entity
  end

  private

  def load_branches
    @branches =
      current_organization
        .branches
        .where(active: true)
        .order(:name)
  end

  def set_branch
    requested_id = params[:branch_id].presence

    @branch =
      if requested_id
        @branches.find(requested_id)
      else
        @branches.find_by(main: true) ||
          @branches.first
      end
  end

  def load_payment_methods
    @payment_methods =
      current_organization
        .payment_methods
        .active
        .alphabetical
  end

  def load_money_accounts
    @money_accounts =
      current_organization
        .money_accounts
        .active
        .receivable
        .where(
          branch_id: [
            nil,
            @branch.id
          ]
        )
        .alphabetical
  end

  def load_existing_settings
    @settings_by_method_id =
      current_organization
        .branch_payment_settings
        .where(
          branch: @branch,
          payment_method: @payment_methods
        )
        .index_by(&:payment_method_id)
  end

  def update_payment_setting!(payment_method)
    attributes =
      submitted_settings.fetch(
        payment_method.id.to_s,
        {}
      )

    enabled =
      ActiveModel::Type::Boolean.new.cast(
        attributes[:enabled]
      )

    money_account =
      selected_money_account(
        payment_method,
        attributes[:money_account_id]
      )

    setting =
      current_organization
        .branch_payment_settings
        .find_or_initialize_by(
          branch: @branch,
          payment_method: payment_method
        )

    setting.assign_attributes(
      enabled: enabled,
      money_account: money_account
    )

    setting.save!
  end

  def selected_money_account(
    payment_method,
    account_id
  )
    return nil unless payment_method.money_account_required?
    return nil if account_id.blank?

    @money_accounts.find(account_id)
  end

  def submitted_settings
    params.fetch(:settings, {})
  end
end
