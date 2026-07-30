module Inventory
  class TransferStock
    def self.call(...)
      new(...).call
    end

    def initialize(
      organization:,
      from_branch:,
      to_branch:,
      item:,
      recorded_by:,
      quantity:,
      transferred_at: Time.current,
      reference: nil,
      notes: nil
    )
      @organization = organization
      @from_branch = from_branch
      @to_branch = to_branch
      @item = item
      @recorded_by = recorded_by
      @quantity = quantity.to_d
      @transferred_at = transferred_at
      @reference = reference
      @notes = notes
    end

    def call
      StockTransfer.transaction do
        transfer = create_transfer!

        post_outgoing_movement!(transfer)
        post_incoming_movement!(transfer)

        transfer
      end
    end

    private

    attr_reader :organization,
                :from_branch,
                :to_branch,
                :item,
                :recorded_by,
                :quantity,
                :transferred_at,
                :reference,
                :notes

    def create_transfer!
      organization.stock_transfers.create!(
        from_branch: from_branch,
        to_branch: to_branch,
        item: item,
        recorded_by: recorded_by,
        quantity: quantity,
        transferred_at: transferred_at,
        reference: reference,
        notes: notes
      )
    end

    def post_outgoing_movement!(transfer)
      Inventory::PostMovement.call(
        organization: organization,
        branch: from_branch,
        item: item,
        recorded_by: recorded_by,
        movement_type: "transfer_out",
        quantity_change: -quantity,
        occurred_at: transferred_at,
        reference: reference,
        notes: notes,
        source: transfer
      )
    end

    def post_incoming_movement!(transfer)
      Inventory::PostMovement.call(
        organization: organization,
        branch: to_branch,
        item: item,
        recorded_by: recorded_by,
        movement_type: "transfer_in",
        quantity_change: quantity,
        occurred_at: transferred_at,
        reference: reference,
        notes: notes,
        source: transfer
      )
    end
  end
end
