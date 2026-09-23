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
    when "benevolence_case.viewed" then "opened a benevolence case"
    when "benevolence_case.opened" then "opened a new benevolence case"
    when "benevolence_case.updated" then "edited a benevolence case"
    when "benevolence.approval_recorded" then "approved a benevolence request (#{Money.format(metadata["amount_cents"])})"
    when "benevolence.denial_recorded" then "denied a benevolence request"
    when "benevolence.approved" then "a benevolence request was approved for #{Money.format(metadata["approved_cents"])}"
    when "benevolence.denied" then "a benevolence request was denied"
    when "benevolence.paid" then "recorded a benevolence payment of #{Money.format(metadata["amount_cents"])}"
    when "social.connected" then "connected Facebook and Instagram (#{metadata["accounts"]} accounts)"
    when "social.deauthorized" then "Meta removed Stewardly's access to Facebook and Instagram"
    when "social.data_deleted" then "Meta asked Stewardly to delete Facebook and Instagram data"
    when "workflow.auto_send_enabled" then "let AI messages in “#{metadata["workflow_name"]}” send without review"
    when "workflow.auto_send_disabled" then "turned off sending without review in “#{metadata["workflow_name"]}”"
    when "church.settings_updated" then "changed church #{metadata.keys.map(&:humanize).map(&:downcase).to_sentence}"
    else action
    end
  end

  def readonly?
    persisted?
  end
end
