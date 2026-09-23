class EventsController < ApplicationController
  before_action :set_event, only: %i[ show edit update destroy publish cancel ]

  def index
    authorize Event
    @events = policy_scope(Event).includes(:occurrences, :ministry).order(created_at: :desc)
    @events = @events.where(status: params[:status]) if Event.statuses.key?(params[:status])
  end

  def show
    @occurrences = @event.occurrences.includes(:registrations)
  end

  def new
    @event = authorize Event.new(organizer: Current.user, ministry_id: params[:ministry_id]), :new?
  end

  def create
    @event = authorize Event.new(event_params.merge(organizer: Current.user))
    first = occurrence_params
    if @event.valid? && Event.transaction { @event.save! && (first.nil? || @event.occurrences.create!(first)) }
      redirect_to edit_event_path(@event), notice: "Event created."
    else
      render :new, status: :unprocessable_content
    end
  rescue ActiveRecord::RecordInvalid => error
    @event.errors.add(:base, error.record.errors.full_messages.to_sentence) unless error.record == @event
    render :new, status: :unprocessable_content
  end

  def edit
    @positions = Position.joins(:team).includes(:team).order("teams.name", :name)
  end

  def update
    @event.assign_attributes(event_params)
    authorize @event
    if @event.save
      redirect_to edit_event_path(@event), notice: "Saved."
    else
      @positions = Position.joins(:team).includes(:team).order("teams.name", :name)
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @event.destroy!
    redirect_to events_path, notice: "Event deleted.", status: :see_other
  end

  def publish
    @event.update!(status: :published)
    redirect_to edit_event_path(@event), notice: "Published.", status: :see_other
  end

  def cancel
    @event.update!(status: :cancelled)
    redirect_to edit_event_path(@event), notice: "Event cancelled.", status: :see_other
  end

  private
    def set_event
      @event = authorize policy_scope(Event).includes(:occurrences, position_needs: :position).find(params.expect(:id))
    end

    def event_params
      params.expect(event: %i[ title slug description ministry_id campus_id location_name address_line1 city region postal_code
        capacity registration_required registration_opens_at registration_closes_at max_party_size visibility registration_form_id ])
    end

    def occurrence_params
      attributes = params.fetch(:first_occurrence, {}).permit(:starts_at, :ends_at)
      attributes[:starts_at].present? ? attributes : nil
    end
end
