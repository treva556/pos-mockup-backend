module Inventory
  class DeductForSale
    def self.call(...)
      new(...).call
    end

    def initialize(
      organization:,
      branch:,
      item:,
      quantity:,
      recorded_by:,
      occurred_at: Time.current,
      reference: nil,
      notes: nil,
      source: nil
    )
      @organization = organization
      @branch = branch
      @item = item
      @quantity = quantity.to_d
      @recorded_by = recorded_by
      @occurred_at = occurred_at || Time.current
      @reference = reference
      @notes = notes
      @source = source
    end

    def call
      validate_context!

      StockMovement.transaction do
        if item.tracks_expiry?
          deduct_from_batches!
        else
          [ post_normal_movement! ]
        end
      end
    end

    private

    attr_reader :organization,
                :branch,
                :item,
                :quantity,
                :recorded_by,
                :occurred_at,
                :reference,
                :notes,
                :source

    def validate_context!
      unless organization&.persisted?
        raise ArgumentError,
              "A saved organization is required"
      end

      unless branch&.organization_id ==
             organization.id
        raise ArgumentError,
              "The branch belongs to another organization"
      end

      unless item&.organization_id ==
             organization.id
        raise ArgumentError,
              "The item belongs to another organization"
      end

      return if quantity.positive?

      raise ArgumentError,
            "Sale quantity must be greater than zero"
    end

    def deduct_from_batches!
      batches =
        organization
          .inventory_batches
          .where(
            branch: branch,
            item: item
          )
          .sellable(occurred_at.to_date)
          .fefo
          .lock
          .to_a

      available =
        batches.sum do |batch|
          batch.quantity_remaining.to_d
        end

      if available < quantity
        raise Inventory::InsufficientStockError,
              insufficient_batch_message(available)
      end

      remaining = quantity
      movements = []

      batches.each do |batch|
        break unless remaining.positive?

        deducted_quantity =
          [
            remaining,
            batch.quantity_remaining.to_d
          ].min

        update_batch!(
          batch: batch,
          deducted_quantity: deducted_quantity
        )

        movements <<
          Inventory::PostMovement.call(
            organization: organization,
            branch: branch,
            item: item,
            recorded_by: recorded_by,
            movement_type: "sale",
            quantity_change:
              -deducted_quantity,
            occurred_at: occurred_at,
            reference: reference,
            notes: notes,
            source: source,
            inventory_batch: batch
          )

        remaining -= deducted_quantity
      end

      movements
    end

    def update_batch!(
      batch:,
      deducted_quantity:
    )
      new_quantity =
        batch.quantity_remaining.to_d -
        deducted_quantity

      batch.update!(
        quantity_remaining: new_quantity,
        status:
          new_quantity.zero? ?
            "depleted" :
            "active"
      )
    end

    def post_normal_movement!
      Inventory::PostMovement.call(
        organization: organization,
        branch: branch,
        item: item,
        recorded_by: recorded_by,
        movement_type: "sale",
        quantity_change: -quantity,
        occurred_at: occurred_at,
        reference: reference,
        notes: notes,
        source: source
      )
    end

    def insufficient_batch_message(available)
      if available.zero?
        "#{item.name} has no unexpired stock " \
          "available at #{branch.name}"
      else
        "#{item.name} only has #{available.to_s('F')} " \
          "units of unexpired stock at #{branch.name}"
      end
    end
  end
end
