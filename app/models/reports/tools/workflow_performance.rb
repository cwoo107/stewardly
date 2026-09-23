class Reports::Tools::WorkflowPerformance < Reports::Tool
  self.tool_name = "workflow_performance"
  self.title = "Workflows"
  self.description = "Each workflow's runs: how many people are in it now, completed, stopped, and failed."
  self.permission = "manage_workflows"

  private
    def call(_args)
      counts = WorkflowRun.group(:workflow_id, :status).count
      rows = Workflow.alphabetical.map do |workflow|
        of = ->(*statuses) { statuses.sum { |status| counts[[ workflow.id, status ]].to_i } }
        [ workflow.name, workflow.status, of.("active", "waiting"), of.("completed"), of.("cancelled", "exited"), of.("failed") ]
      end
      Result.build(figures: { "Workflows" => rows.size, "People in a workflow now" => rows.sum { |r| r[2] } },
        tables: [ table("Workflows", [ "Workflow", "Status", "In it now", "Completed", "Stopped", "Failed" ], rows) ])
    end
end
