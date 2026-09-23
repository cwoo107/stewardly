# Who a campaign goes to: the segment's people (plus anyone a workflow added) with an
# email address, minus suppressed addresses and anyone who opted out of the topic (or
# hasn't opted in to an opt-in topic).
class Campaign::Audience
  def initialize(campaign)
    @campaign = campaign
    @topic = campaign.email_topic
  end

  def people
    return Person.none unless @campaign.segment && @topic

    suppressed = Suppression.for_campaigns(@topic).or(Suppression.blocking_all_mail).where("suppressions.email = people.email")
    extras = CampaignExtraRecipient.where(campaign: @campaign).select(:person_id)
    people = Person.where(id: @campaign.segment.people.select(:id)).or(Person.where(id: extras))
      .where.not(email: nil).where.not(suppressed.arel.exists)
    preference = EmailPreference.where("email_preferences.person_id = people.id").where(email_topic: @topic)

    if @topic.default_subscribed
      people.where.not(preference.where(subscribed: false).arel.exists)
    else
      people.where(preference.where(subscribed: true).arel.exists)
    end
  end

  def count = people.count
end
