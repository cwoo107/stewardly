class Reports::Tools::PathwayFunnel < Reports::Tool
  self.tool_name = "pathway_funnel"
  self.title = "Pathway funnel"
  self.description = "People at each discipleship pathway stage now, the share who moved on to the next stage in the last 12 months, median days to move on, and how many are stuck."
  self.permission = "view_people"

  private
    def call(_args)
      funnel = Pathway::Funnel.new(Pathway.current)
      stuck = PathwayPlacement.stuck.joins(:person).merge(Person.unmerged).group(:pathway_stage_id).count
      rows = funnel.stages.map do |stage|
        conversion = funnel.conversions[stage]
        [ stage.name, funnel.counts[stage], conversion&.dig(:percent), funnel.median_days[stage], stuck[stage.id].to_i ]
      end
      Result.build(figures: { "People on the pathway" => funnel.counts.values.sum, "Stuck" => stuck.values.sum },
        tables: [ table("By stage", [ "Stage", "People now", "Moved on (%)", "Median days to move on", "Stuck" ], rows) ])
    end
end
