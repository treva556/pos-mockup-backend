class BackfillDefaultAccountingCharts < ActiveRecord::Migration[8.0]
  def up
    Organization.find_each do |organization|
      next if organization.ledger_accounts.exists?

      Accounting::ProvisionDefaultChart
        .new(
          organization: organization
        )
        .call
    end
  end

  def down
    # Intentionally irreversible.
    # We do not want to delete accounting data on rollback.
  end
end
