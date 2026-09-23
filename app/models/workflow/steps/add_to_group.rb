class Workflow::Steps::AddToGroup < Workflow::Steps::Base
  self.label = "Add to a group"

  def errors = exists?(Group, "group_id") ? [] : [ "choose a group" ]
  def summary = "Add to #{Group.find_by(id: config["group_id"])&.name || "…"}"

  def perform(run, _execution)
    membership = GroupMembership.find_or_initialize_by(person: run.person, group_id: config["group_id"])
    return Outcome.done("already_member" => true) if membership.persisted?
    return Outcome.skip(membership.errors.full_messages.to_sentence) unless membership.save

    Outcome.done("group_membership_id" => membership.id)
  end
end
