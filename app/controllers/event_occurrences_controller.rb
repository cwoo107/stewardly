class EventOccurrencesController < ApplicationController
  before_action :set_event

  def create
    occurrence = @event.occurrences.new(occurrence_params)
    if occurrence.save
      redirect_to edit_event_path(@event), notice: "Date added.", status: :see_other
    else
      redirect_to edit_event_path(@event), alert: occurrence.errors.full_messages.to_sentence, status: :see_other
    end
  end

  def update
    occurrence = @event.occurrences.find(params.expect(:id))
    occurrence.update!(occurrence_params)
    occurrence.with_lock { occurrence.promote_waitlist! }.each { |r| RegistrationMailer.promoted(r).deliver_later } # capacity may have grown
    redirect_to edit_event_path(@event), notice: "Saved.", status: :see_other
  end

  def destroy
    occurrence = @event.occurrences.find(params.expect(:id))
    if occurrence.registrations.active.any?
      redirect_to edit_event_path(@event), alert: "People are registered for that date. Cancel it instead.", status: :see_other
    else
      occurrence.destroy!
      redirect_to edit_event_path(@event), notice: "Date removed.", status: :see_other
    end
  end

  private
    def set_event
      @event = authorize policy_scope(Event).find(params.expect(:event_id)), :update?
    end

    def occurrence_params
      params.expect(event_occurrence: %i[ starts_at ends_at capacity cancelled ])
    end
end
