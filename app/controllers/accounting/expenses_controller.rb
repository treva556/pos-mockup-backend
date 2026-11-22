module Accounting
  class ExpensesController < ApplicationController
    before_action :authenticate_user!
    before_action :require_organization!
    before_action :require_accounting_management!
    before_action :set_expense,
              only: %i[
                show
                reverse
              ]

    def index
      @expenses =
        current_organization
          .expenses
          .includes(
            :expense_account,
            :money_account,
            :branch,
            :recorded_by
          )
          .recent_first
          .limit(100)
    end

    def new
      @expense =
        current_organization
          .expenses
          .new(
            expense_date: Date.current,
            branch: current_organization.main_branch
          )

      load_form_options
    end

    def create
      load_selected_records

      @expense =
        Expenses::CreateExpense.call(
          organization:
            current_organization,
          recorded_by:
            current_user,
          expense_account:
            @expense_account,
          money_account:
            @money_account,
          expense_date:
            expense_params[:expense_date],
          amount:
            expense_params[:amount],
          branch:
            @branch,
          payee:
            expense_params[:payee],
          reference:
            expense_params[:reference],
          notes:
            expense_params[:notes]
        )

      redirect_to(
        accounting_expenses_path,
        notice:
          "Expense was recorded successfully."
      )
    rescue Expenses::CreateExpense::ExpenseError,
           Accounting::PostJournalEntry::PostingError,
           ActiveRecord::RecordInvalid => error
      @expense ||=
        current_organization
          .expenses
          .new(expense_params)

      load_form_options

      flash.now[:alert] =
        error.message

      render(
        :new,
        status: :unprocessable_entity
      )
    end

    def show
    end

    def reverse
      Expenses::ReverseExpense.call(
        expense: @expense,
        reversed_by: current_user,
        reversal_date:
          params[:reversal_date].presence ||
          Date.current
      )

      redirect_to(
        accounting_expense_path(
          @expense
        ),
        notice:
          "Expense was reversed successfully."
      )
    rescue Expenses::ReverseExpense::ReversalError,
          Accounting::ReverseJournalEntry::ReversalError,
          Accounting::PostJournalEntry::PostingError,
          ActiveRecord::RecordInvalid => error
      redirect_to(
        accounting_expense_path(
          @expense
        ),
        alert:
          error.message
      )
    end

    private

    def load_selected_records
      @expense_account =
        current_organization
          .ledger_accounts
          .where(
            account_type: "expense",
            postable: true,
            active: true
          )
          .find(
            expense_params[:expense_account_id]
          )

      @money_account =
        current_organization
          .money_accounts
          .active
          .payable
          .find(
            expense_params[:money_account_id]
          )

      @branch =
        if expense_params[:branch_id].present?
          current_organization
            .branches
            .where(active: true)
            .find(
              expense_params[:branch_id]
            )
        end
    end

    def load_form_options
      @expense_accounts =
        current_organization
          .ledger_accounts
          .where(
            account_type: "expense",
            postable: true,
            active: true
          )
          .ordered

      @money_accounts =
        current_organization
          .money_accounts
          .active
          .payable
          .includes(:ledger_account)
          .order(:name)

      @branches =
        current_organization
          .branches
          .where(active: true)
          .order(:name)
    end

    def set_expense
      @expense =
        current_organization
          .expenses
          .find(
            params[:id]
          )
    end

    def expense_params
      params
        .require(:expense)
        .permit(
          :expense_date,
          :expense_account_id,
          :money_account_id,
          :branch_id,
          :amount,
          :payee,
          :reference,
          :notes
        )
    end
  end
end
