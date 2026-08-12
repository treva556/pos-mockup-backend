class LedgerAccount < ApplicationRecord
  ACCOUNT_TYPES = {
    asset: "asset",
    liability: "liability",
    equity: "equity",
    revenue: "revenue",
    expense: "expense"
  }.freeze

  NORMAL_BALANCES = {
    debit: "debit",
    credit: "credit"
  }.freeze

  REPORT_GROUPS = {
    current_asset: "current_asset",
    non_current_asset: "non_current_asset",
    contra_asset: "contra_asset",
    current_liability: "current_liability",
    non_current_liability: "non_current_liability",
    equity: "equity",
    revenue: "revenue",
    contra_revenue: "contra_revenue",
    cost_of_sales: "cost_of_sales",
    operating_expense: "operating_expense",
    other_income: "other_income",
    other_expense: "other_expense"
  }.freeze

  REPORT_GROUP_ACCOUNT_TYPES = {
    "current_asset" => "asset",
    "non_current_asset" => "asset",
    "contra_asset" => "asset",
    "current_liability" => "liability",
    "non_current_liability" => "liability",
    "equity" => "equity",
    "revenue" => "revenue",
    "contra_revenue" => "revenue",
    "cost_of_sales" => "expense",
    "operating_expense" => "expense",
    "other_income" => "revenue",
    "other_expense" => "expense"
  }.freeze

  SYSTEM_STRUCTURE_FIELDS = %w[
    code
    name
    parent_id
    account_type
    normal_balance
    report_group
    postable
    active
    system_account
  ].freeze

  belongs_to :organization

  belongs_to :parent,
             class_name: "LedgerAccount",
             optional: true,
             inverse_of: :children

  has_many :children,
           class_name: "LedgerAccount",
           foreign_key: :parent_id,
           inverse_of: :parent,
           dependent: :restrict_with_error

  has_many :money_accounts,
           dependent: :restrict_with_error

  has_many :accounting_account_mappings,
           dependent: :restrict_with_error

  enum :account_type,
       ACCOUNT_TYPES,
       prefix: true,
       validate: true

  enum :normal_balance,
       NORMAL_BALANCES,
       prefix: true,
       validate: true

  enum :report_group,
       REPORT_GROUPS,
       prefix: true,
       validate: true

  before_validation :normalize_details

  validates :code,
            presence: true,
            length: { maximum: 30 },
            uniqueness: {
              scope: :organization_id,
              case_sensitive: false
            }

  validates :name,
            presence: true,
            length: { maximum: 120 }

  validate :report_group_matches_account_type
  validate :parent_belongs_to_same_organization
  validate :parent_is_not_self
  validate :parent_does_not_create_cycle
  validate :parent_account_type_matches
  validate :parent_must_be_heading
  validate :parent_must_be_active
  validate :mapped_account_must_remain_active
  validate :mapped_account_must_remain_postable
  validate :system_account_structure_is_immutable

  scope :active,
        -> { where(active: true) }

  scope :ordered,
        -> { order(:code, :name) }

  scope :postable,
        -> { where(postable: true) }

  def heading?
    !postable?
  end

  private

  def report_group_matches_account_type
    return if report_group.blank?
    return if account_type.blank?

    expected_type =
      REPORT_GROUP_ACCOUNT_TYPES[
        report_group
      ]

    return if expected_type == account_type

    errors.add(
      :report_group,
      "does not match the account type"
    )
  end

  def parent_belongs_to_same_organization
    return if parent.blank?
    return if organization.blank?

    return if parent.organization_id ==
              organization_id

    errors.add(
      :parent,
      "must belong to the same organization"
    )
  end

  def parent_is_not_self
    return if parent.blank?
    return if id.blank?
    return unless parent_id == id

    errors.add(
      :parent,
      "cannot be the account itself"
    )
  end

  def parent_does_not_create_cycle
    return if parent.blank?
    return if id.blank?

    ancestor =
      parent

    while ancestor.present?
      if ancestor.id == id
        errors.add(
          :parent,
          "cannot be a descendant of this account"
        )

        return
      end

      ancestor =
        ancestor.parent
    end
  end

  def parent_account_type_matches
    return if parent.blank?
    return if account_type.blank?
    return if parent.account_type == account_type

    errors.add(
      :parent,
      "must have the same account type"
    )
  end

  def parent_must_be_heading
    return if parent.blank?
    return if parent.heading?

    errors.add(
      :parent,
      "must be a heading account"
    )
  end

  def parent_must_be_active
    return if parent.blank?
    return if parent.active?

    errors.add(
      :parent,
      "must be active"
    )
  end

  def mapped_account_must_remain_active
    return unless persisted?
    return unless will_save_change_to_active?
    return if active?
    return unless accounting_account_mappings.exists?

    errors.add(
      :active,
      "cannot be disabled while used as a system account"
    )
  end

  def mapped_account_must_remain_postable
    return unless persisted?
    return unless will_save_change_to_postable?
    return if postable?
    return unless accounting_account_mappings.exists?

    errors.add(
      :postable,
      "cannot be disabled while used as a system account"
    )
  end

  def system_account_structure_is_immutable
    return unless persisted?
    return unless attribute_in_database("system_account")

    changed =
      SYSTEM_STRUCTURE_FIELDS.select do |attribute|
        will_save_change_to_attribute?(
          attribute
        )
      end

    return if changed.empty?

    errors.add(
      :base,
      "System account structure cannot be changed"
    )
  end

  def normalize_details
    self.code =
      code.to_s.strip.upcase

    self.name =
      name.to_s.strip
  end
end
