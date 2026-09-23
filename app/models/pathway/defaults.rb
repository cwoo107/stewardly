# The pathway every church starts with: Connect → Grow → Serve.
module Pathway::Defaults
  STAGES = [
    { name: "Connect", stuck_after_days: 90, description: "Everyone starts here: guests and people getting to know the church." },
    { name: "Grow", stuck_after_days: 180, description: "In a group or taking a class.",
      definition: { match: "any", conditions: [ { type: "group" }, { type: "course", operator: "enrolled" } ] } },
    { name: "Serve", description: "On a team and serving.",
      definition: { match: "all", conditions: [ { type: "team" }, { type: "serving", times: 1, days: 60 } ] } }
  ].freeze

  def self.install!
    Pathway.transaction do
      pathway = Pathway.create!(name: "Connect, Grow, Serve")
      STAGES.each { |attributes| pathway.stages.create!(attributes) }
      pathway
    end
  end
end
