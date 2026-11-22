module Accounting
  class DashboardController < ApplicationController
    before_action :authenticate_user!
    before_action :require_organization!
    before_action :require_accounting_view!

    def show
    end
  end
end
