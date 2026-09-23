# The nightly check (InsightsSweepJob, 4am church time): runs every detector, keeps one
# live insight per fingerprint, resolves ones whose condition cleared, reopens snoozed
# ones whose snooze is over, and stays quiet about ones staff dismissed while the
# condition lasts.
class Insights::Sweep
  DETECTORS = [
    Insights::Detectors::OverdueTasks, Insights::Detectors::UnownedTasks, Insights::Detectors::VolunteersAtRisk,
    Insights::Detectors::UnderusedVolunteers, Insights::Detectors::StuckOnPathway, Insights::Detectors::NoRecentContact,
    Insights::Detectors::GuestsWithoutFollowUp, Insights::Detectors::UnfilledPositions, Insights::Detectors::GroupsAtCapacity,
    Insights::Detectors::Queues
  ].freeze

  def self.label_for(kind) = DETECTORS.find { |detector| detector.kind == kind }&.label || kind.humanize

  def initialize(church, detectors: DETECTORS)
    @church = church
    @detectors = detectors
  end

  def run!
    now = Time.current
    @detectors.each do |detector_class|
      detector = detector_class.new(@church)
      seen = detector.findings.map { |finding| record(detector, finding, now) }
      Insight.live.where(kind: detector.kind).where.not(fingerprint: seen).find_each { |insight| insight.resolve!(by: nil, resolution: "cleared") }
    end
    Insight.snoozed.where(snoozed_until: ..@church.today).update_all(status: "open", snoozed_until: nil, updated_at: now)
  end

  private
    def record(detector, finding, now)
      fingerprint = detector.fingerprint(finding)
      attributes = {
        kind: detector.kind, subject: finding.subject, person: finding.person, severity: finding.severity, title: finding.title,
        detail: finding.detail, data: finding.data, action_label: finding.action_label, action_path: finding.action_path,
        audience_permission: Insights::Detectors::Queues::QUEUE_PERMISSIONS.fetch(finding.data["queue"], detector.audience_permission),
        audience_user_ids: finding.audience_user_ids, last_seen_at: now
      }

      if (insight = Insight.live.find_by(fingerprint:))
        insight.update!(attributes)
      elsif (dismissed = Insight.dismissed.where(fingerprint:).where(last_seen_at: 36.hours.ago..).first)
        dismissed.update!(last_seen_at: now) # still true, but staff said not to show it
      else
        Insight.create!(attributes.merge(fingerprint:, detected_at: now))
      end
      fingerprint
    end
end
