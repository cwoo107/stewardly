# Someone added to a campaign by a workflow ("enroll in campaign"), even if they're not in its segment.
class CampaignExtraRecipient < ApplicationRecord
  belongs_to :campaign
  belongs_to :person
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  validates :person_id, uniqueness: { scope: :campaign_id }
end
