module Inventory
  class ExpirySummary
    Result =
      Struct.new(
        :expired_batches,
        :expiring_within_7_days,
        :expiring_within_30_days,
        :expiring_within_90_days,
        :expired_quantity,
        :expiring_within_30_days_quantity,
        keyword_init: true
      )

    def self.call(
      organization:,
      branch_id: nil,
      on: Date.current
    )
      new(
        organization: organization,
        branch_id: branch_id,
        on: on
      ).call
    end

    def initialize(
      organization:,
      branch_id:,
      on:
    )
      @organization = organization
      @branch_id = branch_id
      @on = on
    end

    def call
      Result.new(
        expired_batches:
          expired_scope.count,
        expiring_within_7_days:
          expiring_scope(7).count,
        expiring_within_30_days:
          expiring_scope(30).count,
        expiring_within_90_days:
          expiring_scope(90).count,
        expired_quantity:
          expired_scope
            .sum(:quantity_remaining)
            .to_d,
        expiring_within_30_days_quantity:
          expiring_scope(30)
            .sum(:quantity_remaining)
            .to_d
      )
    end

    private

    attr_reader :organization,
                :branch_id,
                :on

    def base_scope
      scope =
        organization
          .inventory_batches
          .with_quantity

      if branch_id.present?
        scope =
          scope.where(
            branch_id: branch_id
          )
      end

      scope
    end

    def expired_scope
      base_scope.where(
        "expires_on < ?",
        on
      )
    end

    def expiring_scope(days)
      base_scope.where(
        expires_on:
          on..(on + days.days)
      )
    end
  end
end
