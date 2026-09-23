# The interface every giving platform adapter implements. The rest of the app only
# talks to this.
class Giving::Provider
  class Error < StandardError; end
  class InvalidWebhook < StandardError; end

  FundRecord = Data.define(:external_id, :name, :active)
  # status: succeeded | refunded | failed. amount_cents is always positive; refunds use status.
  DonationRecord = Data.define(:external_id, :donor_external_id, :donor_name, :donor_email, :fund_external_id,
    :amount_cents, :currency, :given_on, :method, :status)

  def name = raise(NotImplementedError)

  # All funds (FundRecords).
  def funds = raise(NotImplementedError)

  # DonationRecords given between the dates, yielded page by page.
  def each_donation(since:, until:, &) = raise(NotImplementedError)

  # Raises InvalidWebhook unless the request really came from the provider.
  def verify_webhook!(request) = raise(NotImplementedError)

  # DonationRecords in a stored WebhookEvent (a webhook may carry several, or none).
  def donations_from(webhook_event) = raise(NotImplementedError)
end
