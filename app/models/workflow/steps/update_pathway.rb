# Re-checks the person's pathway stage now. Stages come from facts (groups, serving, …),
# so this can't force a stage; follow it with an If / else on "Pathway stage".
class Workflow::Steps::UpdatePathway < Workflow::Steps::Base
  self.label = "Update pathway stage"

  def summary = "Re-check pathway stage"

  def perform(run, _execution)
    Pathway::Placement.new(Pathway.current).place!(run.person)
    Outcome.done("stage" => run.person.reload.pathway_placement&.pathway_stage&.name)
  end
end
