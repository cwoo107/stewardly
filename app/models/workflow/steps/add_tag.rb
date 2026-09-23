class Workflow::Steps::AddTag < Workflow::Steps::Base
  self.label = "Add a tag"

  def errors = exists?(Tag, "tag_id") ? [] : [ "choose a tag" ]
  def summary = "Tag #{Tag.find_by(id: config["tag_id"])&.name || "…"}"

  def perform(run, _execution)
    Tagging.find_or_create_by!(person: run.person, tag_id: config["tag_id"])
    Outcome.done
  rescue ActiveRecord::RecordNotUnique
    Outcome.done
  end
end
