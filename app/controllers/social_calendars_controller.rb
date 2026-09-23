# Scheduled and published posts by day, with upcoming public events that don't have a post yet.
class SocialCalendarsController < ApplicationController
  def show
    authorize SocialPost, :index?
    @month = (Date.iso8601("#{params[:month]}-01") rescue nil) || Current.church.today.beginning_of_month
    range = Calendar::Month.range_for(@month)
    zone = Current.church.zone
    posts = policy_scope(SocialPost).where.not(status: "cancelled").includes(targets: :social_account)
      .where("COALESCE(social_posts.published_at, social_posts.scheduled_at) BETWEEN ? AND ?", range.first.in_time_zone(zone), range.last.in_time_zone(zone).end_of_day)
    @posts_by_date = posts.group_by { |post| (post.published_at || post.scheduled_at).in_time_zone(zone).to_date }
    promoted = SocialPost.where.not(event_id: nil).distinct.pluck(:event_id)
    @events_by_date = EventOccurrence.upcoming.joins(:event).merge(Event.published.where(visibility: "public")).where(starts_at: range.first.in_time_zone(zone)..range.last.in_time_zone(zone).end_of_day)
      .includes(:event).group_by { |occurrence| occurrence.starts_at.in_time_zone(zone).to_date }
    @promoted = promoted.to_set
  end
end
