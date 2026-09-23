class Insights::Detectors::OverdueTasks < Insights::Detector
  self.kind = "overdue_task"
  self.label = "Overdue tasks"
  self.audience_permission = "manage_tasks"

  def findings
    Task.where.not(status: "done").where(due_on: ...@today).includes(:owner).map do |task|
      days = (@today - task.due_on).to_i
      Finding.build(subject: task, severity: days > 7 || task.priority_urgent? ? "high" : "medium",
        title: "“#{task.title.truncate(80)}” is #{plural(days, "day")} overdue", detail: task.owner ? "Assigned to #{task.owner.name}." : "Nobody owns it.",
        data: { "days_overdue" => days }, action_label: "Open task", action_path: edit_task_path(task), audience_user_ids: [ task.owner_id ])
    end
  end
end
