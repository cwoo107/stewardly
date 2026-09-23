# Logs a follow-up with the person who asked for prayer. It lands on their
# timeline as a sensitive touchpoint; the request text itself is never copied.
class PrayerFollowUpsController < ApplicationController
  def create
    @prayer_request = authorize policy_scope(PrayerRequest).find(params.expect(:prayer_request_id)), :follow_up?
    follow_up = @prayer_request.follow_ups.new(person: @prayer_request.person, author: Current.user, kind: :prayer_follow_up,
      sensitive: true, summary: "Prayer follow-up", body: params.dig(:follow_up, :body), occurred_at: Time.current)

    if follow_up.save
      redirect_to @prayer_request, notice: "Follow-up logged.", status: :see_other
    else
      redirect_to @prayer_request, alert: follow_up.errors.full_messages.to_sentence, status: :see_other
    end
  end
end
