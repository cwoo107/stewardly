# Makes a user a leader of one ministry: they manage its groups and teams
# without needing church-wide manage_ministries.
class MinistryLeadership < ApplicationRecord
  belongs_to :ministry
  belongs_to :user
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  validates :user_id, uniqueness: { scope: :ministry_id, message: "already leads this ministry" }

  after_create { AuditEvent.record!(action: "ministry_leader.added", auditable: user, metadata: audit_metadata) }
  after_destroy { AuditEvent.record!(action: "ministry_leader.removed", auditable: user, metadata: audit_metadata) }

  private
    def audit_metadata
      { ministry_id: ministry.id, ministry_name: ministry.name, user_name: user.name }
    end
end
