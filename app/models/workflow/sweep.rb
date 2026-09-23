# The daily check for triggers that aren't events: "missed N weeks" and "N days
# before/after a date". Runs once a day per church (WorkflowSweepJob), and at most one
# run per person per workflow per day, so a rerun of the sweep starts no one twice.
class Workflow::Sweep
  def initialize(church)
    @church = church
  end

  def run!
    Workflow.active.where(trigger_type: Workflow::Trigger::SWEPT).includes(:current_version).find_each do |workflow|
      trigger = workflow.published_definition.trigger
      people_for(trigger, workflow).find_each { |person| Workflow::Enrollment.new(workflow, person).start!(once_per_day: true) }
    end
  end

  def people_for(trigger, workflow)
    case trigger.type
    when "missed_weeks" then missed(trigger["weeks"].to_i, workflow)
    when "date_relative" then on_date(trigger["date_field"], trigger["days"].to_i)
    else Person.none
    end
  end

  private
    # Attended at least twice before the window, not at all during it, and not already
    # started on this workflow since their last visit (one run per absence).
    def missed(weeks, workflow)
      cutoff = @church.now - weeks.weeks
      last_visit = Attendance.where("attendances.person_id = people.id").select("MAX(attendances.checked_in_at)")
      Person.where(merged_into_id: nil)
        .where(id: Attendance.where(checked_in_at: ...cutoff).group(:person_id).having("COUNT(*) >= 2").select(:person_id))
        .where.not(id: Attendance.where(checked_in_at: cutoff..).select(:person_id))
        .where.not(workflow.runs.where("workflow_runs.person_id = people.id").where("workflow_runs.started_at > (#{last_visit.to_sql})").arel.exists)
    end

    # People whose date (shifted by days) is today, in the church's time zone. Birthdays repeat yearly.
    def on_date(field, days)
      target = @church.today - days
      people = Person.where(merged_into_id: nil)
      case field
      when "created_at"
        people.where("(people.created_at AT TIME ZONE 'UTC' AT TIME ZONE ?)::date = ?", @church.zone.tzinfo.name, target)
      when "birthdate"
        people.where("EXTRACT(MONTH FROM birthdate) = ? AND EXTRACT(DAY FROM birthdate) = ?", target.month, target.day)
      when /\Acustom:([a-z][a-z0-9_]*)\z/
        people.where("people.custom_fields ->> ? = ?", Regexp.last_match(1), target.iso8601)
      else Person.none
      end
    end
end
