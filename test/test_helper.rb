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

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)

    include TestRecordHelpers
  end
end
