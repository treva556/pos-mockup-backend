module Accounting
  class GeneralLedgerController < ApplicationController
    before_action :authenticate_user!
    before_action :require_organization!
    before_action :require_accounting_view!

    def show
      load_filter_options

      @ledger_account =
        selected_ledger_account

      @branch =
        selected_branch

      @from_date =
        parsed_date(
          params[:from_date]
        ) ||
        Date.current.beginning_of_month

      @to_date =
        parsed_date(
          params[:to_date]
        ) ||
        Date.current

      return if @ledger_account.blank?

      @general_ledger =
        Accounting::Reports::GeneralLedger.call(
          organization:
            current_organization,
          ledger_account:
            @ledger_account,
          from_date:
            @from_date,
          to_date:
            @to_date,
          branch:
            @branch
        )
    rescue ArgumentError => error
      @report_error =
        error.message
    end

    private

    def load_filter_options
      @ledger_accounts =
        current_organization
          .ledger_accounts
          .postable
          .ordered

      @branches =
        current_organization
          .branches
          .where(
            active: true
          )
          .order(:name)
    end

    def selected_ledger_account
      account_id =
        params[:ledger_account_id]

      if account_id.present?
        current_organization
          .ledger_accounts
          .postable
          .find(
            account_id
          )
      else
        @ledger_accounts.first
      end
    end

    def selected_branch
      return if params[:branch_id].blank?

      current_organization
        .branches
        .where(
          active: true
        )
        .find(
          params[:branch_id]
        )
    end

    def parsed_date(value)
      return if value.blank?

      Date.iso8601(
        value.to_s
      )
    rescue ArgumentError
      nil
    end
  end
end
