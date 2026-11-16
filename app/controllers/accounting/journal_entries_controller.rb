module Accounting
  class JournalEntriesController < ApplicationController
    before_action :authenticate_user!
    before_action :require_organization!
    before_action :require_accounting_view!

    before_action :set_journal_entry,
                  only: :show

    def index
      @query =
        params[:q].to_s.strip

      @status =
        params[:status]
          .to_s
          .presence_in(
            %w[
              draft
              posted
              reversed
              all
            ]
          ) || "all"

      @from_date =
        parsed_date(
          params[:from_date]
        )

      @to_date =
        parsed_date(
          params[:to_date]
        )

      scope =
        current_organization
          .journal_entries
          .includes(
            :created_by,
            :source
          )
          .recent_first

      scope =
        apply_query(scope)

      scope =
        apply_status(scope)

      scope =
        apply_date_range(scope)

      @journal_entries =
        scope
    end

    def show
      @journal_lines =
        @journal_entry
          .journal_lines
          .includes(
            :ledger_account,
            :branch
          )
          .ordered
    end

    private

    def set_journal_entry
      @journal_entry =
        current_organization
          .journal_entries
          .includes(
            :created_by,
            :source
          )
          .find(
            params[:id]
          )
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
          journal_entries.entry_number ILIKE :query
          OR journal_entries.description ILIKE :query
          OR journal_entries.source_type ILIKE :query
        SQL
        query: "%#{escaped}%"
      )
    end

    def apply_status(scope)
      return scope if @status == "all"

      scope.where(
        status: @status
      )
    end

    def apply_date_range(scope)
      scope =
        scope.where(
          entry_date:
            @from_date..
        ) if @from_date.present?

      scope =
        scope.where(
          entry_date:
            ..@to_date
        ) if @to_date.present?

      scope
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
