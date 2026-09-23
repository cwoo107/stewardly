# Finds a published event for its public page: public events for anyone,
# members-only events for signed-in users, never drafts or internal events.
module PublicEventLookup
  extend ActiveSupport::Concern

  private
    def set_public_event
      @event = Event.includes(:occurrences, registration_form: :fields).published
        .where(visibility: %w[ public members ]).find_by!(slug: params.expect(:slug))
      request_authentication if @event.visibility_members? && Current.user.nil?
    end
end
