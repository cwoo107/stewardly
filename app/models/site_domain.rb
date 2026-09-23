# A church's own domain for its website. It works once DNS points at us: a CNAME to
# sites_cname_target (www.gracechurch.org), or A records to sites_apex_ips for a bare
# domain (gracechurch.org). Verified domains get HTTPS automatically (TlsChecksController).
class SiteDomain < ApplicationRecord
  HOSTNAME = /\A(?=.{4,253}\z)([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}\z/

  belongs_to :site
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  enum :status, { pending: "pending", verified: "verified", failed: "failed" }, default: :pending, validate: true

  normalizes :hostname, with: ->(hostname) { hostname.to_s.strip.downcase.delete_prefix("http://").delete_prefix("https://").split("/").first.to_s.delete_suffix(".") }

  validates :hostname, presence: true, format: { with: HOSTNAME, message: "must be a domain like www.gracechurch.org" }
  validate :hostname_is_available
  validate :not_our_own_domain

  after_commit :forget_cached_host

  def self.verified_host?(hostname)
    return false if hostname.blank?

    Rails.cache.fetch([ "site_domain_verified", hostname.downcase ], expires_in: 1.minute) do
      ActsAsTenant.without_tenant { verified.exists?(hostname: hostname.downcase) }
    end
  end

  def apex? = hostname.count(".") == 1

  def verify!
    result = Site::DnsCheck.new(hostname).call
    attributes = { last_checked_at: Time.current, last_check_result: result.message }
    if result.ok
      update!(attributes.merge(status: :verified, verified_at: verified_at || Time.current))
      site.domains.where.not(id:).update_all(primary: false) if site.domains.verified.where(primary: true).none?
      update!(primary: true) if site.domains.verified.where(primary: true).none?
    else
      update!(attributes.merge(status: created_at < 7.days.ago ? :failed : (verified? ? :verified : :pending)))
    end
    result
  end

  def make_primary!
    transaction do
      site.domains.update_all(primary: false)
      update!(primary: true)
    end
  end

  private
    def hostname_is_available
      taken = ActsAsTenant.without_tenant { SiteDomain.where(hostname:).where.not(id:).exists? }
      errors.add(:hostname, "is already connected to another site") if taken
    end

    def not_our_own_domain
      ours = [ Rails.configuration.x.app_domain, Rails.configuration.x.sites_domain ]
      errors.add(:hostname, "is one of Stewardly's own addresses") if ours.any? { |domain| hostname == domain || hostname.to_s.end_with?(".#{domain}") }
    end

    def forget_cached_host
      Rails.cache.delete([ "site_domain_verified", hostname ])
    end
end
