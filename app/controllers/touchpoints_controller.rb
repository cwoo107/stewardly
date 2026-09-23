class TouchpointsController < ApplicationController
  def create
    person = policy_scope(Person).find(params.expect(:person_id))
    @touchpoint = authorize person.touchpoints.new(touchpoint_params.merge(author: Current.user))

    if Touchpoint::MANUAL_KINDS.include?(@touchpoint.kind) && @touchpoint.save
      redirect_to person, notice: "#{@touchpoint.kind.humanize} logged."
    else
      redirect_to person, alert: "Couldn't log that: #{@touchpoint.errors.full_messages.to_sentence.presence || "choose a kind"}"
    end
  end

  private
    def touchpoint_params
      params.expect(touchpoint: %i[ kind summary body occurred_at ])
    end
end
