module Accounting
  class AccountingPeriodsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_organization!
    before_action :require_accounting_management!

    before_action :set_accounting_period,
                  only: :close

    def index
      @accounting_periods =
        current_organization
          .accounting_periods
          .includes(
            :closed_by
          )
          .chronological
    end

    def new
      @accounting_period =
        current_organization
          .accounting_periods
          .new(
            status: "open"
          )
    end

    def create
      @accounting_period =
        current_organization
          .accounting_periods
          .new(
            accounting_period_params
          )

      @accounting_period.status =
        "open"

      if @accounting_period.save
        redirect_to(
          accounting_accounting_periods_path,
          notice:
            "#{@accounting_period.name} was created."
        )
      else
        render :new,
               status: :unprocessable_entity
      end
    end

    def close
      @accounting_period.assign_attributes(
        status: "closed",
        closed_at: Time.current,
        closed_by: current_user
      )

      if @accounting_period.save
        redirect_to(
          accounting_accounting_periods_path,
          notice:
            "#{@accounting_period.name} was closed."
        )
      else
        redirect_to(
          accounting_accounting_periods_path,
          alert:
            @accounting_period
              .errors
              .full_messages
              .to_sentence
        )
      end
    end

    private

    def set_accounting_period
      @accounting_period =
        current_organization
          .accounting_periods
          .find(
            params[:id]
          )
    end

    def accounting_period_params
      params.require(
        :accounting_period
      ).permit(
        :name,
        :starts_on,
        :ends_on
      )
    end
  end
end
