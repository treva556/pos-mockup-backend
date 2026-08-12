class JournalEntry < ApplicationRecord
  STATUSES = {
    draft: "draft",
    posted: "posted",
    reversed: "reversed"
  }.freeze

  LOCKED_STATUSES = %w[
    posted
    reversed
  ].freeze

  belongs_to :organization

  belongs_to :created_by,
             class_name: "User"

  belongs_to :source,
             polymorphic: true,
             optional: true

  belongs_to :reversal_of,
             class_name: "JournalEntry",
             optional: true,
             inverse_of: :reversal_entry

  has_one :reversal_entry,
          class_name: "JournalEntry",
          foreign_key: :reversal_of_id,
          inverse_of: :reversal_of,
          dependent: :restrict_with_error

  has_many :journal_lines,
           -> { order(:line_number) },
           dependent: :restrict_with_error,
           inverse_of: :journal_entry

  enum :status,
       STATUSES,
       prefix: true,
       validate: true

  before_validation :normalize_details

  before_update :prevent_locked_entry_changes
  before_destroy :prevent_locked_entry_destroy

  validates :entry_number,
            presence: true,
            length: {
              maximum: 50
            },
            uniqueness: {
              scope: :organization_id,
              case_sensitive: false
            }

  validates :source_id,
            uniqueness: {
              scope: %i[
                organization_id
                source_type
              ],
              message:
                "already has a journal entry"
            },
            allow_nil: true

  validates :reversal_of_id,
            uniqueness: true,
            allow_nil: true

  validates :entry_date,
            presence: true

  validates :description,
            length: {
              maximum: 250
            },
            allow_blank: true

  validate :created_by_is_active_member
  validate :source_belongs_to_organization
  validate :reversal_of_belongs_to_organization
  validate :reversal_cannot_reference_self

  validate :new_entry_must_start_as_draft,
           on: :create

  validate :status_transition_requires_service,
           on: :update

  scope :recent_first,
        lambda {
          order(
            entry_date: :desc,
            created_at: :desc
          )
        }

  scope :for_accounting_period,
        lambda { |starts_on, ends_on|
          where(
            entry_date:
              starts_on..ends_on
          )
        }

  def total_debits
    journal_lines
      .sum(:debit)
      .to_d
  end

  def total_credits
    journal_lines
      .sum(:credit)
      .to_d
  end

  def balanced?
    journal_lines.any? &&
      total_debits ==
        total_credits
  end

  def locked?
    status_posted? ||
      status_reversed?
  end

  private

  def normalize_details
    self.entry_number =
      entry_number.to_s.strip.upcase

    self.description =
      description.to_s.strip.presence
  end

  def created_by_is_active_member
    return if created_by.blank?
    return if organization.blank?

    return if organization
      .memberships
      .active
      .exists?(
        user_id: created_by_id
      )

    errors.add(
      :created_by,
      "must be an active organization member"
    )
  end

  def source_belongs_to_organization
    return if source.blank?
    return if organization.blank?

    unless source.respond_to?(
      :organization_id
    )
      errors.add(
        :source,
        "must belong to an organization"
      )

      return
    end

    return if source.organization_id ==
              organization_id

    errors.add(
      :source,
      "must belong to the same organization"
    )
  end

  def reversal_of_belongs_to_organization
    return if reversal_of.blank?
    return if organization.blank?

    return if reversal_of.organization_id ==
              organization_id

    errors.add(
      :reversal_of,
      "must belong to the same organization"
    )
  end

  def reversal_cannot_reference_self
    return if reversal_of_id.blank?
    return if id.blank?
    return unless reversal_of_id == id

    errors.add(
      :reversal_of,
      "cannot be the journal entry itself"
    )
  end

  def new_entry_must_start_as_draft
    return if status_draft?

    errors.add(
      :status,
      "must start as draft"
    )
  end

  def status_transition_requires_service
    return unless will_save_change_to_status?

    errors.add(
      :status,
      "must be changed through the accounting lifecycle service"
    )
  end

  def prevent_locked_entry_changes
    previous_status =
      attribute_in_database(
        "status"
      )

    return unless LOCKED_STATUSES.include?(
      previous_status
    )

    errors.add(
      :base,
      "Posted or reversed journal entries cannot be changed"
    )

    throw :abort
  end

  def prevent_locked_entry_destroy
    return unless locked?

    errors.add(
      :base,
      "Posted or reversed journal entries cannot be deleted"
    )

    throw :abort
  end
end
