# Append-only record of an important admin action. Actor and IP come from Current,
# so callers only say what happened and to what.
class AuditEvent < ApplicationRecord
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :auditable, polymorphic: true
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  validates :action, presence: true

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  def self.record!(action:, auditable:, metadata: {})
    create!(action:, auditable:, metadata:, actor: Current.user, ip_address: Current.ip_address)
  end

  def description
    case action
    when "role.granted" then "granted #{metadata["role_name"]} to #{metadata["user_name"]}"
    when "role.revoked" then "revoked #{metadata["role_name"]} from #{metadata["user_name"]}"
    when "user.deleted" then "removed the account for #{metadata["email_address"]}"
    when "church.settings_updated" then "changed church #{metadata.keys.map(&:humanize).map(&:downcase).to_sentence}"
    else action
    end
  end

  def readonly?
    persisted?
  end
end
