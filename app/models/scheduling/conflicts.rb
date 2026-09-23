# A person's other commitments on the same local day: other assignments (any team,
# service, or event) and blockouts.
class Scheduling::Conflicts
  def initialize(assignment)
    @assignment = assignment
  end

  def other_assignments
    Assignment.active.on(@assignment.local_date).where(person_id: @assignment.person_id)
      .where.not(id: @assignment.id).where.not(schedulable: @assignment.schedulable)
  end

  def blocked_out?
    Blockout.covering(@assignment.local_date).exists?(person_id: @assignment.person_id)
  end

  def any? = blocked_out? || other_assignments.exists?

  def messages
    messages = other_assignments.includes(:schedulable, :position).map { |other| "Also serving #{other.position.name} at #{other.title}" }
    messages.unshift("Blocked out that day") if blocked_out?
    messages
  end
end
