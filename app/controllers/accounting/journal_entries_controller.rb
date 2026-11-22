module Accounting
  class JournalEntriesController < ApplicationController
    before_action :authenticate_user!
    before_action :require_organization!

    before_action :require_accounting_view!,
                  only: %i[index show]

    before_action :require_accounting_management!,
                  only: %i[new create]

    before_action :set_journal_entry,
                  only: :show

    before_action :load_manual_journal_options,
                  only: %i[new create]

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

    def new
      @manual_journal =
        default_manual_journal
    end

    def create
      @manual_journal =
        manual_journal_params.to_h

      journal_entry =
        Accounting::CreateJournalEntry.call(
          organization:
            current_organization,
          created_by:
            current_user,
          entry_date:
            manual_entry_date,
          description:
            @manual_journal["description"],
          lines:
            manual_journal_lines,
          post: true
        )

      redirect_to(
        accounting_journal_entry_path(
          journal_entry
        ),
        notice:
          "#{journal_entry.entry_number} was posted successfully."
      )
    rescue ActiveRecord::RecordInvalid,
           Accounting::PostJournalEntry::PostingError => error
      @manual_journal_errors =
        [ error.message ]

      render :new,
             status: :unprocessable_entity
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

    def load_manual_journal_options
      @ledger_accounts =
        current_organization
          .ledger_accounts
          .where(
            active: true,
            postable: true
          )
          .order(:code)

      @branches =
        current_organization
          .branches
          .where(
            active: true
          )
          .order(:name)
    end

    def default_manual_journal
      {
        "entry_date" =>
          Date.current.iso8601,
        "description" =>
          "",
        "lines" =>
          Array.new(2) {
            {
              "ledger_account_id" => "",
              "branch_id" => "",
              "description" => "",
              "debit" => "",
              "credit" => ""
            }
          }
      }
    end

    def manual_journal_params
      params.require(
        :manual_journal
      ).permit(
        :entry_date,
        :description,
        lines: %i[
          ledger_account_id
          branch_id
          description
          debit
          credit
        ]
      )
    end

    def manual_entry_date
      Date.iso8601(
        @manual_journal.fetch(
          "entry_date"
        ).to_s
      )
    rescue ArgumentError
      raise ActiveRecord::RecordInvalid.new(
        JournalEntry.new.tap do |entry|
          entry.errors.add(
            :entry_date,
            "is invalid"
          )
        end
      )
    end

    def manual_journal_lines
      raw_lines =
        @manual_journal
          .fetch(
            "lines",
            {}
          )
          .values

      raw_lines
        .reject {
          |line|
          manual_line_blank?(line)
        }
        .map {
          |line|
          build_manual_line(line)
        }
    end

    def manual_line_blank?(line)
      line.values.all? {
        |value|
        value.blank?
      }
    end

    def build_manual_line(line)
      account_id =
        line["ledger_account_id"]

      if account_id.blank?
        raise Accounting::PostJournalEntry::PostingError,
              "Each journal line must select an account"
      end

      account =
        current_organization
          .ledger_accounts
          .where(
            active: true,
            postable: true
          )
          .find(
            account_id
          )

      branch =
        if line["branch_id"].present?
          current_organization
            .branches
            .where(
              active: true
            )
            .find(
              line["branch_id"]
            )
        end

      {
        ledger_account:
          account,
        branch:
          branch,
        description:
          line["description"],
        debit:
          decimal_amount(
            line["debit"]
          ),
        credit:
          decimal_amount(
            line["credit"]
          )
      }
    end

    def decimal_amount(value)
      return 0.to_d if value.blank?

      BigDecimal(
        value.to_s
      )
    rescue ArgumentError
      0.to_d
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
