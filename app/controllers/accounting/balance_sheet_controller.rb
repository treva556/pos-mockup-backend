module Accounting
  class BalanceSheetController < ApplicationController
    before_action :authenticate_user!
    before_action :require_organization!
    before_action :require_accounting_view!

    def show
      load_filter_options

      @branch =
        selected_branch

      @as_of_date =
        parsed_date(
          params[:as_of_date]
        ) ||
        Date.current

      @balance_sheet =
        Accounting::Reports::BalanceSheet.call(
          organization:
            current_organization,
          as_of_date:
            @as_of_date,
          branch:
            @branch
        )
    rescue ArgumentError => error
      @report_error =
        error.message
    end

    private

    def load_filter_options
      @branches =
        current_organization
          .branches
          .where(active: true)
          .order(:name)
    end

    def selected_branch
      return if params[:branch_id].blank?

      current_organization
        .branches
        .where(active: true)
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
