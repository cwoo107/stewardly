module SocialHelper
  STATUS_COLORS = { "draft" => "gray", "scheduled" => "violet", "publishing" => "amber", "published" => "green", "partly_failed" => "amber",
    "failed" => "rose", "cancelled" => "gray", "pending" => "violet", "unknown" => "amber" }.freeze

  def social_status_badge(record) = badge(record.status.humanize, color: STATUS_COLORS.fetch(record.status, "gray"))

  def social_when(post)
    time = post.published_at || post.scheduled_at
    time ? l(time.in_time_zone(Current.church.zone), format: :long) : "Not scheduled"
  end
end
