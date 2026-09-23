# The interface for syncing a segment to an outside email tool, for churches that
# keep sending from Mailchimp and friends. Returns how many people were sent over.
class Email::AudienceSync
  def sync!(people) = raise(NotImplementedError)
end
