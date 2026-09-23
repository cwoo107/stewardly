module InsightsHelper
  SEVERITY_COLORS = { "high" => "rose", "medium" => "amber", "low" => "gray" }.freeze

  def severity_badge(insight) = badge(insight.severity.humanize, color: SEVERITY_COLORS.fetch(insight.severity))

  def assignable_users
    @assignable_users ||= User.includes(:roles, :person, :ministry_leaderships).alphabetical.select(&:admin_area?).map { |user| [ user.name, user.id ] }
  end
end
