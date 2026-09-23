class Workflow::Steps::RemoveTag < Workflow::Steps::Base
  self.label = "Remove a tag"

  def errors = exists?(Tag, "tag_id") ? [] : [ "choose a tag" ]
  def summary = "Remove tag #{Tag.find_by(id: config["tag_id"])&.name || "…"}"

  def perform(run, _execution)
    Tagging.where(person: run.person, tag_id: config["tag_id"]).destroy_all
    Outcome.done
  end
end
