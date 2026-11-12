module Accounting
  class AccountResolver
    class ConfigurationError < StandardError; end

    def self.mapped!(
      organization:,
      role:
    )
      mapping =
        organization
          .accounting_account_mappings
          .includes(
            :ledger_account
          )
          .find_by(
            role: role
          )

      account =
        mapping&.ledger_account

      unless account
        raise ConfigurationError,
              "Accounting account mapping #{role} is missing"
      end

      validate_account!(
        account: account,
        organization: organization,
        label: role
      )

      account
    end

    def self.money!(
      organization:,
      money_account:
    )
      unless money_account&.organization_id ==
             organization.id
        raise ConfigurationError,
              "Money account belongs to another organization"
      end

      account =
        money_account.ledger_account

      unless account
        raise ConfigurationError,
              "#{money_account.name} is not linked to a ledger account"
      end

      validate_account!(
        account: account,
        organization: organization,
        label: money_account.name
      )

      account
    end

    def self.validate_account!(
      account:,
      organization:,
      label:
    )
      unless account.organization_id ==
             organization.id
        raise ConfigurationError,
              "#{label} ledger account belongs to another organization"
      end

      unless account.active?
        raise ConfigurationError,
              "#{label} ledger account is inactive"
      end

      return if account.postable?

      raise ConfigurationError,
            "#{label} ledger account is not postable"
    end

    private_class_method :validate_account!
  end
end
