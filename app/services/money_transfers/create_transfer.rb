module MoneyTransfers
  class CreateTransfer
    def self.call(
      organization:,
      recorded_by:,
      from_money_account:,
      to_money_account:,
      attributes:
    )
      new(
        organization: organization,
        recorded_by: recorded_by,
        from_money_account: from_money_account,
        to_money_account: to_money_account,
        attributes: attributes
      ).call
    end

    def initialize(
      organization:,
      recorded_by:,
      from_money_account:,
      to_money_account:,
      attributes:
    )
      @organization =
        organization

      @recorded_by =
        recorded_by

      @from_money_account =
        from_money_account

      @to_money_account =
        to_money_account

      @attributes =
        attributes
    end

    def call
      MoneyTransfer.transaction do
        transfer =
          organization
            .money_transfers
            .create!(
              attributes.merge(
                recorded_by:
                  recorded_by,
                from_money_account:
                  from_money_account,
                to_money_account:
                  to_money_account
              )
            )

        MoneyTransfers::PostTransferAccounting.call(
          organization: organization,
          transfer: transfer
        )

        transfer
      end
    rescue ActiveRecord::RecordInvalid => error
      raise MoneyTransfers::TransferError,
            error.record.errors.full_messages.to_sentence
    end

    private

    attr_reader :organization,
                :recorded_by,
                :from_money_account,
                :to_money_account,
                :attributes
  end
end
