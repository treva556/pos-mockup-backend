module Accounting
  class LedgerAccountsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_organization!
    before_action :require_accounting_view!

    before_action :require_accounting_management!,
                  except: :index

    before_action :set_ledger_account,
                  only: %i[
                    edit
                    update
                    toggle_status
                  ]

    before_action :prevent_system_account_change!,
                  only: %i[
                    edit
                    update
                    toggle_status
                  ]

    def index
      @query =
        params[:q].to_s.strip

      @status =
        params[:status]
          .to_s
          .presence_in(
            %w[
              active
              inactive
              all
            ]
          ) || "active"

      @account_type =
        params[:account_type].to_s

      scope =
        current_organization
          .ledger_accounts
          .includes(:parent)
          .ordered

      scope =
        apply_query(
          scope
        )

      scope =
        apply_status(
          scope
        )

      scope =
        apply_account_type(
          scope
        )

      @ledger_accounts =
        scope
    end

    def new
      @ledger_account =
        current_organization
          .ledger_accounts
          .new(
            account_type: "asset",
            normal_balance: "debit",
            report_group: "current_asset",
            postable: true,
            active: true,
            system_account: false
          )

      load_form_options
    end

    def create
      @ledger_account =
        current_organization
          .ledger_accounts
          .new(
            ledger_account_params
          )

      @ledger_account.active =
        true

      @ledger_account.system_account =
        false

      if @ledger_account.save
        redirect_to accounting_ledger_accounts_path,
                    notice:
                      "Ledger account created."
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
      if @ledger_account.update(
        ledger_account_params
      )
        redirect_to accounting_ledger_accounts_path,
                    notice:
                      "Ledger account updated."
      else
        load_form_options

        render :edit,
               status: :unprocessable_entity
      end
    end

    def toggle_status
      @ledger_account.active =
        !@ledger_account.active?

      if @ledger_account.save
        redirect_to accounting_ledger_accounts_path,
                    notice:
                      "Ledger account status updated."
      else
        redirect_to accounting_ledger_accounts_path,
                    alert:
                      @ledger_account
                        .errors
                        .full_messages
                        .to_sentence
      end
    end

    private

    def set_ledger_account
      @ledger_account =
        current_organization
          .ledger_accounts
          .find(
            params[:id]
          )
    end

    def prevent_system_account_change!
      return unless @ledger_account.system_account?

      redirect_to accounting_ledger_accounts_path,
                  alert:
                    "System accounts cannot be changed."
    end

    def ledger_account_params
      params
        .require(:ledger_account)
        .permit(
          :code,
          :name,
          :parent_id,
          :account_type,
          :normal_balance,
          :report_group,
          :postable
        )
    end

    def load_form_options
      @parent_accounts =
        current_organization
          .ledger_accounts
          .active
          .where(
            postable: false
          )
          .where
          .not(
            id: @ledger_account.id
          )
          .ordered
    end

    def apply_query(scope)
      return scope if @query.blank?

      escaped =
        ActiveRecord::Base
          .sanitize_sql_like(
            @query
          )

      scope.where(
        <<~SQL.squish,
          ledger_accounts.code ILIKE :query
          OR ledger_accounts.name ILIKE :query
        SQL
        query: "%#{escaped}%"
      )
    end

    def apply_status(scope)
      case @status
      when "active"
        scope.where(
          active: true
        )
      when "inactive"
        scope.where(
          active: false
        )
      else
        scope
      end
    end

    def apply_account_type(scope)
      return scope unless LedgerAccount::ACCOUNT_TYPES
        .value?(
          @account_type
        )

      scope.where(
        account_type: @account_type
      )
    end
  end
end
