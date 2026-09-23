class UserRole < ApplicationRecord
  belongs_to :user
  belongs_to :role
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  validates :role_id, uniqueness: { scope: :user_id, message: "is already granted" }

  before_destroy :keep_at_least_one_church_admin
  after_create :audit_grant
  after_destroy :audit_revocation

  private
    def keep_at_least_one_church_admin
      return unless role.church_admin? && role.user_roles.count == 1

      errors.add(:base, "A church must keep at least one church admin")
      throw :abort
    end

    def audit_grant
      AuditEvent.record!(action: "role.granted", auditable: user, metadata: audit_metadata)
    end

    def audit_revocation
      AuditEvent.record!(action: "role.revoked", auditable: user, metadata: audit_metadata)
    end

    def audit_metadata
      { role_id: role.id, role_key: role.key, role_name: role.name, user_name: user.name }
    end
end
