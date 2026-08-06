module Inventory
  class AssignExistingStockBatch
    def self.call(...)
      new(...).call
    end

    def initialize(
      organization:,
      branch:,
      item:,
      batch_number: nil,
      manufactured_on: nil,
      expires_on:,
      unit_cost: nil,
      received_at: Time.current
    )
      @organization = organization
      @branch = branch
      @item = item
      @batch_number = batch_number.to_s.strip.presence
      @manufactured_on = cast_date(manufactured_on)
      @expires_on = cast_date(expires_on)
      @unit_cost = unit_cost
      @received_at = received_at || Time.current
    end

    def call
      validate_context!

      InventoryBatch.transaction do
        stock_level =
          organization.stock_levels.find_by!(
            branch: branch,
            item: item
          )

        stock_level.with_lock do
          quantity =
            unassigned_quantity(stock_level)

          unless quantity.positive?
            raise Inventory::BatchAssignmentError,
                  "#{item.name} has no stock awaiting batch assignment"
          end

          organization.inventory_batches.create!(
            branch: branch,
            item: item,
            batch_number: batch_number,
            manufactured_on: manufactured_on,
            expires_on: expires_on,
            quantity_received: quantity,
            quantity_remaining: quantity,
            unit_cost: resolved_unit_cost,
            received_at: received_at,
            status: "active"
          )
        end
      end
    end

    private

    attr_reader :organization,
                :branch,
                :item,
                :batch_number,
                :manufactured_on,
                :expires_on,
                :unit_cost,
                :received_at

    def validate_context!
      unless organization&.persisted?
        raise Inventory::BatchAssignmentError,
              "A saved organization is required"
      end

      unless branch&.organization_id == organization.id
        raise Inventory::BatchAssignmentError,
              "The branch belongs to another organization"
      end

      unless item&.organization_id == organization.id
        raise Inventory::BatchAssignmentError,
              "The product belongs to another organization"
      end

      unless item.tracks_expiry?
        raise Inventory::BatchAssignmentError,
              "#{item.name} does not use expiry tracking"
      end

      if expires_on.blank?
        raise Inventory::BatchAssignmentError,
              "Enter an expiry date"
      end

      return if manufactured_on.blank?
      return if manufactured_on <= expires_on

      raise Inventory::BatchAssignmentError,
            "Manufacture date cannot be after the expiry date"
    end

    def unassigned_quantity(stock_level)
      assigned_quantity =
        organization.inventory_batches
          .where(
            branch: branch,
            item: item
          )
          .sum(:quantity_remaining)
          .to_d

      stock_level.quantity_on_hand.to_d -
        assigned_quantity
    end

    def resolved_unit_cost
      value =
        unit_cost.presence ||
        item.purchase_cost

      value.to_d.round(2)
    end

    def cast_date(value)
      return if value.blank?

      ActiveModel::Type::Date
        .new
        .cast(value)
    end
  end
end
