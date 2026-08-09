module AuditImmutable
  extend ActiveSupport::Concern

  included do
    before_update :prevent_audit_record_update
    before_destroy :prevent_audit_record_destroy
  end

  private

  def audit_record_immutable?
    true
  end

  def prevent_audit_record_update
    return unless audit_record_immutable?

    errors.add(
      :base,
      "#{self.class.model_name.human} is an immutable audit record"
    )

    throw :abort
  end

  def prevent_audit_record_destroy
    return unless audit_record_immutable?

    errors.add(
      :base,
      "#{self.class.model_name.human} is an immutable audit record"
    )

    throw :abort
  end
end
