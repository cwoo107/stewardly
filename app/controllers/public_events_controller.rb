# Public event pages at /e/:slug. Members-only events need a member area sign-in.
class PublicEventsController < ApplicationController
  include PublicEventLookup

  allow_unauthenticated_access
  skip_after_action :verify_authorized # visibility is enforced by PublicEventLookup
  before_action :resume_session
  before_action :set_public_event

  layout "public"

  def show
    @occurrences = @event.upcoming_occurrences
  end
end
