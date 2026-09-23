# Mailchimp, through its official Marketing API gem. Upserts a segment's people into
# a list (audience), 500 at a time.
#
# TODO(verify vendor docs): the batch_list_members call, its members payload (email_address,
# status_if_new, merge_fields FNAME/LNAME) and update_existing flag are from memory of the
# Mailchimp Marketing API. spec/models/email/audience_syncs/mailchimp_spec.rb stays pending until checked.
class Email::AudienceSyncs::Mailchimp < Email::AudienceSync
  BATCH_SIZE = 500

  def initialize(integration)
    @integration = integration
  end

  def sync!(people)
    people.where.not(email: nil).in_batches(of: BATCH_SIZE).sum do |batch|
      members = batch.map do |person|
        { email_address: person.email, status_if_new: "subscribed", merge_fields: { FNAME: person.first_name, LNAME: person.last_name } }
      end
      client.lists.batch_list_members(@integration.setting(:list_id), { members:, update_existing: true })
      members.size
    end
  rescue MailchimpMarketing::ApiError => error
    raise Email::DeliveryProvider::Error, error.message
  end

  private
    def client
      MailchimpMarketing::Client.new.tap do |client|
        client.set_config(api_key: @integration.credential(:api_key), server: @integration.setting(:server_prefix))
      end
    end
end
