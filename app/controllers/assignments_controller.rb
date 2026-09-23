# Board actions: drop a volunteer into a slot, move them between slots, change status, remove.
class AssignmentsController < ApplicationController
  def create
    schedulable = find_schedulable(params.expect(assignment: %i[ schedulable_type schedulable_id ]))
    @assignment = authorize schedulable.assignments.new(position: Position.find(params.dig(:assignment, :position_id)),
      person: Person.unmerged.find(params.dig(:assignment, :person_id)), assigned_by: Current.user)
    @assignment.save
    render_cell(@assignment)
  end

  # Ranked candidates for one slot, loaded lazily into the board.
  def suggestions
    @occurrence = find_schedulable(params)
    @position = Position.find(params.expect(:position_id))
    authorize @occurrence.assignments.new(position: @position), :create?
    @candidates = Scheduling::Candidates.new(occurrence: @occurrence, position: @position).all.first(5)
    @frame_id = "suggestions_#{Scheduling::Board::Cell.new(occurrence: @occurrence, position: @position, assignments: [], needed: 0).dom_id}"
  end

  def update
    @assignment = authorize Assignment.find(params.expect(:id))
    previous = [ @assignment.schedulable, @assignment.position ]
    attributes = params.expect(assignment: %i[ schedulable_type schedulable_id position_id status ])

    @assignment.schedulable = find_schedulable(attributes) if attributes[:schedulable_id]
    @assignment.position = Position.find(attributes[:position_id]) if attributes[:position_id]
    @assignment.status = attributes[:status] if attributes[:status].in?(Assignment.statuses.keys)
    authorize @assignment # the destination must be schedulable by this user too
    @assignment.save
    render_cell(@assignment, previous:)
  end

  def destroy
    @assignment = authorize Assignment.find(params.expect(:id))
    @assignment.destroy!
    render_cell(@assignment)
  end

  private
    # Scheduling is never blocked by load, but the leader hears about it.
    def load_warning(assignment)
      load = @board.load_for(assignment)
      "#{assignment.person.name} is now at risk of burnout: #{load.reasons.to_sentence}." if load.at_risk? && !assignment.declined?
    end

    def find_schedulable(attributes)
      type = attributes[:schedulable_type].presence_in(Assignment::SCHEDULABLE_TYPES) or raise ActiveRecord::RecordNotFound
      type.constantize.find(attributes[:schedulable_id])
    end

    # Re-renders the affected board cells (source and destination) as Turbo Streams.
    def render_cell(assignment, previous: nil)
      team = assignment.position.team
      @board = Scheduling::Board.new(team:, range: assignment.local_date..assignment.local_date)
      @cells = [ [ assignment.schedulable, assignment.position ], previous ].compact.uniq.map { |occurrence, position| @board.cell(occurrence, position) }
      @team = team
      @load_warning = load_warning(assignment) if assignment.persisted? && !assignment.destroyed? && assignment.errors.empty?
      respond_to do |format|
        format.turbo_stream { render "assignments/cells", status: assignment.errors.any? ? :unprocessable_content : :ok }
        format.html { redirect_to team_schedule_path(team, from: assignment.local_date), alert: assignment.errors.full_messages.to_sentence.presence, status: :see_other }
      end
    end
end
