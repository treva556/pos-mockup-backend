ENV["RAILS_ENV"] ||= "test"

require_relative "../config/environment"
require "rails/test_help"
require "securerandom"

module TestRecordHelpers
  def create_user(overrides = {})
    token = SecureRandom.hex(6)

    User.create!(
      {
        name: "Test User",
        email: "user-#{token}@example.com",
        password: "Password123!",
        password_confirmation: "Password123!",
        active: true
      }.merge(overrides)
    )
  end

  def create_organization(overrides = {})
    token = SecureRandom.hex(5)

    Organization.create!(
      {
        name: "Test Organization #{token}",
        country_code: "KE",
        currency_code: "KES",
        time_zone: "Africa/Nairobi",
        active: true
      }.merge(overrides)
    )
  end

  def create_branch(organization:, overrides: {})
    token = SecureRandom.hex(4).upcase

    organization.branches.create!(
      {
        name: "Branch #{token}",
        code: "B#{token}",
        main: false,
        active: true
      }.merge(overrides)
    )
  end
end

def create_money_account(organization:, overrides: {})
  token = SecureRandom.hex(4)

  defaults = {
    name: "Money Account #{token}",
    account_type: "cash",
    opening_balance: 1_000,
    opening_balance_date: Date.current,
    can_receive: true,
    can_pay: true,
    active: true
  }

  organization.money_accounts.create!(
    defaults.merge(overrides)
  )
end

def create_payment_method(organization:, overrides: {})
  token = SecureRandom.hex(4).upcase

  defaults = {
    name: "Payment Method #{token}",
    code: "PM#{token}",
    payment_type: "cash",
    requires_reference: false,
    active: true
  }

  organization.payment_methods.create!(
    defaults.merge(overrides)
  )
end

def create_money_transfer(
    organization:,
    recorded_by:,
    from_account:,
    to_account:,
    overrides: {}
  )
    defaults = {
      amount: 100,
      transferred_at: Time.current,
      reference: "TRANSFER-#{SecureRandom.hex(4).upcase}"
    }

    organization.money_transfers.create!(
      defaults.merge(
        from_money_account: from_account,
        to_money_account: to_account,
        recorded_by: recorded_by
      ).merge(overrides)
    )
  end

def create_unit_of_measure(organization:, overrides: {})
  token = SecureRandom.hex(4)
  attributes = overrides.dup

  defaults = {
    name: "Piece #{token}",
    symbol: "pc#{token}",
    decimal_allowed: false,
    active: true
  }

  organization.unit_of_measures.create!(
    defaults.merge(attributes)
  )
end

def create_inventory_item(organization:, overrides: {})
  token = SecureRandom.hex(4)
  attributes = overrides.dup

  unit =
    attributes.delete(:unit_of_measure) ||
    create_unit_of_measure(organization: organization)

  defaults = {
    name: "Inventory Item #{token}",
    unit_of_measure: unit,
    item_type: "product",
    selling_price: 100,
    purchase_cost: 60,
    track_inventory: true,
    active: true
  }

  organization.items.create!(
    defaults.merge(attributes)
  )
end

def create_stock_level(
  organization:,
  branch:,
  item:,
  overrides: {}
)
  defaults = {
    quantity_on_hand: 0,
    reorder_level: 0
  }

  organization.stock_levels.create!(
    defaults.merge(
      branch: branch,
      item: item
    ).merge(overrides)
  )
end

# 1. Define the module first
module IntegrationTestHelpers
  TEST_PASSWORD = "Password123!".freeze

  def sign_in_as(user, password: TEST_PASSWORD)
    post login_path,
         params: {
           email: user.email,
           password: password
         }
  end

  def provision_organization_for(user, overrides = {})
    token = SecureRandom.hex(5)

    Organizations::Provision.call(
      user: user,
      organization_attributes: {
        name: "Test Business #{token}",
        email: "business-#{token}@example.com",
        country_code: "KE",
        currency_code: "KES",
        time_zone: "Africa/Nairobi",
        active: true
      }.merge(overrides)
    )
  end
end

# 2. Then include it in ActiveSupport::TestCase
class ActiveSupport::TestCase
  parallelize(workers: :number_of_processors)

  include TestRecordHelpers
  include IntegrationTestHelpers
end

# 3. And include it in ActionDispatch::IntegrationTest
module ActionDispatch
  class IntegrationTest
    include IntegrationTestHelpers
  end
end
