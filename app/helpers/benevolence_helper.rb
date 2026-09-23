module BenevolenceHelper
  STATUS_COLORS = { "submitted" => "cyan", "under_review" => "violet", "approved" => "green", "denied" => "gray", "fulfilled" => "gray" }.freeze

  def benevolence_status_badge(kase) = badge(kase.status.humanize, color: STATUS_COLORS.fetch(kase.status))
  def benevolence_flag_badge(flag) = badge(flag.label, color: flag.severity == "warning" ? "amber" : "gray")

  def benevolence_team_options
    User.includes(:roles, :person).alphabetical.select { |user| user.can?(:manage_benevolence) || user.can?(:approve_benevolence) }.map { |user| [ user.name, user.id ] }
  end
end
