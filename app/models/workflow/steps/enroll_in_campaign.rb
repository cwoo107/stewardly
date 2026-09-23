# Adds the person to a campaign that hasn't gone out yet, even if they're not in its segment.
class Workflow::Steps::EnrollInCampaign < Workflow::Steps::Base
  self.label = "Add to a campaign"

  def errors = exists?(Campaign, "campaign_id") ? [] : [ "choose a campaign" ]
  def summary = "Add to campaign “#{Campaign.find_by(id: config["campaign_id"])&.name || "…"}”"

  def perform(run, _execution)
    campaign = Campaign.find_by(id: config["campaign_id"])
    return Outcome.skip("The campaign was deleted") unless campaign
    return Outcome.skip("“#{campaign.name}” was already #{campaign.status}") unless campaign.editable?

    CampaignExtraRecipient.find_or_create_by!(campaign:, person: run.person)
    Outcome.done("campaign_id" => campaign.id)
  rescue ActiveRecord::RecordNotUnique
    Outcome.done("campaign_id" => campaign.id)
  end
end
