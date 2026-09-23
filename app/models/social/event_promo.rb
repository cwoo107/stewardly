# A draft post promoting a published public event: never published without a person.
class Social::EventPromo
  def initialize(event)
    @event = event
    @church = event.church
  end

  # The draft, or nil (not public, turned off, already has one, or nothing ahead on its calendar).
  def draft!(force: false)
    return unless @event.published? && @event.visibility_public?
    return unless force || @church.social_event_promos?
    return SocialPost.find_by(event: @event, source: "event_promo") if SocialPost.exists?(event: @event, source: "event_promo")

    occurrence = @event.occurrences.upcoming.chronological.first or return
    post = SocialPost.new(event: @event, source: "event_promo", link_url: "#{Site.current.base_url}/e/#{@event.slug}", body: body(occurrence))
    post.account_ids = SocialAccount.usable.where(network: "facebook_page").ids # Instagram needs a photo; staff can add one and tick it
    post.save!
    post
  rescue ActiveRecord::RecordNotUnique
    SocialPost.find_by(event: @event, source: "event_promo")
  end

  private
    def body(occurrence)
      when_text = "#{I18n.l(occurrence.starts_at.in_time_zone(@church.zone).to_date, format: :long)} at #{occurrence.starts_at.in_time_zone(@church.zone).strftime("%-l:%M %p")}"
      [ "📅 #{@event.title}", when_text + (@event.location_summary.present? ? " · #{@event.location_summary}" : ""),
        @event.description.to_s.squish.truncate(220).presence, "Everyone is welcome. Details and sign-up at the link." ].compact.join("\n\n")
    end
end
