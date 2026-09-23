module WorkflowsHelper
  RUN_COLORS = { "active" => "cyan", "waiting" => "violet", "completed" => "green", "exited" => "gray", "cancelled" => "gray", "failed" => "rose" }.freeze
  STATUS_COLORS = { "draft" => "gray", "active" => "green", "paused" => "amber" }.freeze

  def workflow_status_badge(workflow) = badge(workflow.status.humanize, color: STATUS_COLORS.fetch(workflow.status))
  def run_status_badge(run) = badge(run.status.humanize, color: RUN_COLORS.fetch(run.status))

  def step_summary(step) = Workflow::Steps.for(step).summary

  # People who can be given tasks or notified: anyone with a staff-side role.
  def staff_user_options
    @staff_user_options ||= User.includes(:roles, :person, :ministry_leaderships).alphabetical.select(&:admin_area?).map { |user| [ user.name, user.id ] }
  end
end
