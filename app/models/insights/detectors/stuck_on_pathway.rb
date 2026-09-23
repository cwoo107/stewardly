class Insights::Detectors::StuckOnPathway < Insights::Detector
  self.kind = "stuck_on_pathway"
  self.label = "People stuck on the pathway"
  self.audience_permission = "manage_pathways"

  def findings
    PathwayPlacement.stuck.joins(:person).merge(Person.unmerged).group(:pathway_stage_id).count.filter_map do |stage_id, count|
      stage = PathwayStage.find_by(id: stage_id) or next
      Finding.build(subject: stage, severity: count >= 10 ? "medium" : "low",
        title: "#{plural(count, "person")} stuck in #{stage.name} for over #{stage.stuck_after_days} days",
        data: { "count" => count, "stuck_after_days" => stage.stuck_after_days }, action_label: "See who", action_path: pathway_path)
    end
  end
end
