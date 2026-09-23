class Member::AssignmentsController < Member::BaseController
  def index
    @assignments = person.assignments.upcoming(today).where.not(status: "declined").includes(:schedulable, position: :team)
    @blockouts = person.blockouts.current(today)
    @blockout = person.blockouts.new(starts_on: today + 1)
  end

  def update
    assignment = person.assignments.find(params.expect(:id))
    authorize assignment, :respond?
    return redirect_to(member_assignments_path, alert: "This date has passed.") unless assignment.respondable?

    params.expect(:answer) == "accept" ? assignment.accept! : assignment.decline!
    AssignmentMailer.declined(assignment).deliver_later if assignment.declined?
    redirect_to member_assignments_path, notice: assignment.accepted? ? "Thanks for serving!" : "Thanks for letting us know.", status: :see_other
  end
end
