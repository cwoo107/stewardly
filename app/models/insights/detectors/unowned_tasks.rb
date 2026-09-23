class Insights::Detectors::UnownedTasks < Insights::Detector
  self.kind = "tasks_without_owner"
  self.label = "Tasks without an owner"
  self.audience_permission = "manage_tasks"

  def findings
    tasks = Task.where(status: %w[ todo in_progress ], owner_id: nil).where(created_at: ...2.days.ago)
    count = tasks.count
    return [] if count.zero?

    [ Finding.build(severity: count > 5 ? "medium" : "low", title: "#{plural(count, "task")} to do with nobody assigned",
      detail: tasks.order(:created_at).limit(3).pluck(:title).map { |title| "“#{title.truncate(60)}”" }.to_sentence,
      data: { "count" => count }, action_label: "Open the board", action_path: tasks_path) ]
  end
end
