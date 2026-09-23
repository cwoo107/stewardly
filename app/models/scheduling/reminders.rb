# The morning reminder run for one church: volunteers N days ahead (church setting)
# and event registrants the day before. Each goes out once.
class Scheduling::Reminders
  def initialize(church)
    @church = church
  end

  def send_due!
    volunteer_reminders + event_reminders
  end

  private
    def volunteer_reminders
      date = @church.today + @church.reminder_days_before
      Assignment.active.on(date).where(reminded_at: nil).includes(:schedulable).select { |a| !a.schedulable.cancelled? }.each do |assignment|
        AssignmentMailer.reminder(assignment).deliver_later
        assignment.update_column(:reminded_at, Time.current)
      end.size
    end

    def event_reminders
      EventOccurrence.where(local_date: @church.today + 1, cancelled: false, reminders_sent_at: nil).includes(:registrations).sum do |occurrence|
        occurrence.registrations.confirmed.each { |registration| RegistrationMailer.reminder(registration).deliver_later }
        occurrence.update_column(:reminders_sent_at, Time.current)
        occurrence.registrations.confirmed.size
      end
    end
end
