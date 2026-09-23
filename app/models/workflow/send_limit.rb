# The church-wide cap on workflow emails per day (church time zone). Sends over the
# limit wait for the next day rather than being dropped.
class Workflow::SendLimit
  RESUME_HOUR = 8

  def initialize(church)
    @church = church
  end

  def sent_today
    Delivery.where.not(workflow_step_execution_id: nil).where(created_at: @church.now.beginning_of_day..).count
  end

  def reached? = sent_today >= @church.workflow_daily_send_limit

  def next_opening = (@church.now + 1.day).change(hour: RESUME_HOUR)
end
