module MoneyTransfers
  class PostTransferAccounting
    def self.call(
      organization:,
      transfer:
    )
      new(
        organization: organization,
        transfer: transfer
      ).call
    end

    def initialize(
      organization:,
      transfer:
    )
      @organization = organization
      @transfer = transfer
    end

    def call
      validate_transfer!

      existing =
        existing_journal

      return existing if existing

      Accounting::CreateJournalEntry.call(
        organization: organization,
        created_by:
          transfer.recorded_by,
        source: transfer,
        entry_date:
          transfer.transferred_at.to_date,
        description:
          journal_description,
        lines:
          journal_lines
      )
    rescue Accounting::AccountResolver::ConfigurationError,
           Accounting::PostJournalEntry::PostingError,
           ActiveRecord::RecordInvalid => error
      raise MoneyTransfers::TransferError,
            "Accounting posting failed: #{error.message}"
    end

    private

    attr_reader :organization,
                :transfer

    def existing_journal
      organization
        .journal_entries
        .find_by(
          source: transfer
        )
    end

    def validate_transfer!
      unless transfer&.persisted?
        raise MoneyTransfers::TransferError,
              "A saved money transfer is required"
      end

      unless transfer.organization_id ==
             organization.id
        raise MoneyTransfers::TransferError,
              "The money transfer belongs to another organization"
      end

      return if transfer.amount.to_d.positive?

      raise MoneyTransfers::TransferError,
            "Transfer amount must be greater than zero"
    end

    def journal_description
      description =
        "Transfer from #{transfer.from_money_account.name} " \
        "to #{transfer.to_money_account.name}"

      return description if transfer.reference.blank?

      "#{description} (#{transfer.reference})"
    end

    def journal_lines
      [
        {
          ledger_account:
            destination_ledger_account,
          branch:
            transfer.to_money_account.branch,
          debit:
            transfer.amount.to_d,
          credit: 0,
          description:
            "Transfer into #{transfer.to_money_account.name}"
        },
        {
          ledger_account:
            source_ledger_account,
          branch:
            transfer.from_money_account.branch,
          debit: 0,
          credit:
            transfer.amount.to_d,
          description:
            "Transfer out of #{transfer.from_money_account.name}"
        }
      ]
    end

    def source_ledger_account
      Accounting::AccountResolver.money!(
        organization: organization,
        money_account:
          transfer.from_money_account
      )
    end

    def destination_ledger_account
      Accounting::AccountResolver.money!(
        organization: organization,
        money_account:
          transfer.to_money_account
      )
    end
  end
end
