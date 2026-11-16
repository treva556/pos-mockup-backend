class JournalLine < ApplicationRecord
  belongs_to :organization

  belongs_to :journal_entry,
             inverse_of: :journal_lines

  belongs_to :ledger_account

  belongs_to :branch,
             optional: true

  before_validation :normalize_amounts

  before_destroy :prevent_destroy_when_journal_locked

  validates :line_number,
            numericality: {
              only_integer: true,
              greater_than: 0
            },
            uniqueness: {
              scope: :journal_entry_id
            }

  validates :debit,
            :credit,
            numericality: {
              greater_than_or_equal_to: 0
            }

  validates :description,
            length: {
              maximum: 250
            },
            allow_blank: true

  validate :exactly_one_side_has_amount
  validate :journal_entry_belongs_to_organization
  validate :ledger_account_belongs_to_organization
  validate :branch_belongs_to_organization
  validate :ledger_account_is_postable
  validate :ledger_account_is_available_for_new_line
  validate :journal_entry_must_be_draft

  scope :ordered,
        -> { order(:line_number) }

  def debit?
    debit.to_d.positive?
  end

  def credit?
    credit.to_d.positive?
  end

  def amount
    debit? ?
      debit.to_d :
      credit.to_d
  end

  private

  def normalize_amounts
    self.debit =
      debit.to_d

    self.credit =
      credit.to_d

    self.description =
      description.to_s.strip.presence
  end

  def exactly_one_side_has_amount
    debit_positive =
      debit.to_d.positive?

    credit_positive =
      credit.to_d.positive?

    return if debit_positive ^ credit_positive

    errors.add(
      :base,
      "Journal line must contain either a debit or a credit"
    )
  end

  def journal_entry_belongs_to_organization
    return if journal_entry.blank?
    return if organization.blank?

    return if journal_entry.organization_id ==
              organization_id

    errors.add(
      :journal_entry,
      "must belong to the same organization"
    )
  end

  def ledger_account_belongs_to_organization
    return if ledger_account.blank?
    return if organization.blank?

    return if ledger_account.organization_id ==
              organization_id

    errors.add(
      :ledger_account,
      "must belong to the same organization"
    )
  end

  def branch_belongs_to_organization
    return if branch.blank?
    return if organization.blank?

    return if branch.organization_id ==
              organization_id

    errors.add(
      :branch,
      "must belong to the same organization"
    )
  end

  def ledger_account_is_postable
    return if ledger_account.blank?
    return if ledger_account.postable?

    errors.add(
      :ledger_account,
      "must be a postable account"
    )
  end

  def ledger_account_is_available_for_new_line
    return if ledger_account.blank?

    check_required =
      new_record? ||
      will_save_change_to_ledger_account_id?

    return unless check_required
    return if ledger_account.active?

    errors.add(
      :ledger_account,
      "must be active"
    )
  end

  def journal_entry_must_be_draft
    return if journal_entry.blank?
    return if journal_entry.status_draft?

    errors.add(
      :journal_entry,
      "must be draft before journal lines can be changed"
    )
  end

  def prevent_destroy_when_journal_locked
    return if journal_entry.blank?
    return if journal_entry.status_draft?

    errors.add(
      :base,
      "Posted journal lines cannot be deleted"
    )

    throw :abort
  end
end
