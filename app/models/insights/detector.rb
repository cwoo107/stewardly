# Base for the nightly checks. A detector returns Findings; Insights::Sweep turns them
# into Insight records (one live insight per fingerprint).
class Insights::Detector
  include Rails.application.routes.url_helpers

  Finding = Data.define(:subject, :person, :severity, :title, :detail, :data, :action_label, :action_path, :audience_user_ids) do
    def self.build(title:, severity: "medium", subject: nil, person: nil, detail: nil, data: {}, action_label: nil, action_path: nil, audience_user_ids: [])
      new(subject:, person:, severity:, title:, detail:, data:, action_label:, action_path:, audience_user_ids: audience_user_ids.compact.uniq)
    end
  end

  class_attribute :kind, :label, :audience_permission

  def initialize(church)
    @church = church
    @today = church.today
  end

  def findings = raise(NotImplementedError)

  def fingerprint(finding)
    [ kind, finding.subject&.class&.name, finding.subject&.id ].compact.join(":")
  end

  private
    def default_url_options = {}

    def ministry_leader_ids(ministry_ids)
      MinistryLeadership.where(ministry_id: Array(ministry_ids).compact).pluck(:user_id)
    end

    def plural(count, word) = ActionController::Base.helpers.pluralize(count, word)
end
