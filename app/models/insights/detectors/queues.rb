# Work waiting in queues: donors to match, messages to approve, benevolence decisions,
# failed workflow runs. Counts only, never the private contents.
class Insights::Detectors::Queues < Insights::Detector
  self.kind = "queue"
  self.label = "Waiting for someone"
  self.audience_permission = "view_insights" # each finding narrows it (see Insights::Sweep)

  QUEUE_PERMISSIONS = { "unmatched_donors" => "manage_giving", "pending_messages" => "approve_messages",
    "benevolence_decisions" => "approve_benevolence", "failed_workflow_runs" => "manage_workflows",
    "social_attention" => "manage_social" }.freeze

  def findings
    [ unmatched_donors, pending_messages, benevolence_decisions, *failed_runs, social_attention ].compact
  end

  def fingerprint(finding) = "queue:#{finding.data["queue"]}:#{finding.subject&.id}"

  private
    def unmatched_donors
      donors = Donation.in_review.distinct.count(Arel.sql("COALESCE(donor_external_id, 'gift-' || id::text)"))
      return if donors.zero?

      Finding.build(severity: "low", title: "#{plural(donors, "donor")} waiting to be matched", data: { "queue" => "unmatched_donors", "count" => donors },
        action_label: "Review queue", action_path: donation_matches_path)
    end

    def pending_messages
      drafts = MessageDraft.pending
      count = drafts.count
      return if count.zero?

      oldest = (@today - drafts.minimum(:created_at).in_time_zone(@church.zone).to_date).to_i
      Finding.build(severity: oldest >= 2 ? "high" : "medium", title: "#{plural(count, "message")} waiting for approval", detail: oldest.zero? ? "The oldest arrived today." : "The oldest has waited #{plural(oldest, "day")}.",
        data: { "queue" => "pending_messages", "count" => count, "oldest_days" => oldest }, action_label: "Approvals", action_path: message_drafts_path)
    end

    def benevolence_decisions
      count = BenevolenceCase.where(status: %w[ submitted under_review ]).count
      return if count.zero?

      Finding.build(severity: "medium", title: "#{plural(count, "benevolence request")} waiting for a decision", data: { "queue" => "benevolence_decisions", "count" => count },
        action_label: "Benevolence", action_path: benevolence_cases_path)
    end

    def social_attention
      posts = SocialPost.needs_attention.count
      accounts = SocialAccount.needs_reconnect.count
      return if (posts + accounts).zero?

      parts = [ (plural(posts, "social post") + " didn't fully go out" if posts.positive?), (plural(accounts, "social account") + " need reconnecting" if accounts.positive?) ].compact
      Finding.build(severity: accounts.positive? ? "high" : "medium", title: parts.join("; ").upcase_first, data: { "queue" => "social_attention", "posts" => posts, "accounts" => accounts },
        action_label: "Review", action_path: accounts.positive? ? social_accounts_path : social_posts_path(tab: "attention"))
    end

    def failed_runs
      WorkflowRun.failed.where(finished_at: 14.days.ago..).group(:workflow_id).count.filter_map do |workflow_id, count|
        workflow = Workflow.find_by(id: workflow_id) or next
        Finding.build(subject: workflow, severity: "medium", title: "#{plural(count, "run")} of “#{workflow.name}” failed",
          data: { "queue" => "failed_workflow_runs", "count" => count }, action_label: "See runs", action_path: workflow_runs_path(workflow, status: "failed"))
      end
    end
end
