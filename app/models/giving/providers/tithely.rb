# Tithe.ly.
#
# TODO(verify vendor docs): EVERYTHING in this adapter that touches Tithe.ly is unverified,
# because no Tithe.ly API documentation has been provided yet. That covers the base URL,
# authentication, fund and transaction endpoints, pagination, field names, how refunds
# appear, and how webhooks are signed. Each method raises Giving::Provider::Error until
# it's been written against the real docs. spec/models/giving/providers/tithely_spec.rb has
# pending examples that fail until then. The rest of Giving (import, matching,
# reconciliation, the review queue) is built and tested against the interface.
class Giving::Providers::Tithely < Giving::Provider
  UNVERIFIED = "The Tithe.ly connection isn't finished yet: it needs Tithe.ly's API documentation (see Giving::Providers::Tithely)."

  def initialize(integration)
    @integration = integration
  end

  def name = "tithely"

  def funds = raise(Error, UNVERIFIED)
  def each_donation(since:, until:) = raise(Error, UNVERIFIED)

  # TODO(verify vendor docs): Tithe.ly's webhook signing scheme. Until then every webhook is
  # rejected, so nothing unverified is ever stored as real giving.
  def verify_webhook!(_request) = raise(InvalidWebhook, UNVERIFIED)

  def donations_from(_webhook_event) = raise(Error, UNVERIFIED)
end
