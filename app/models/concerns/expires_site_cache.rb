# Records that appear on church websites (events, groups, forms, services, campuses):
# changing one clears the church's cached pages so live sections stay current.
module ExpiresSiteCache
  extend ActiveSupport::Concern

  included do
    after_commit :expire_site_cache
  end

  private
    def expire_site_cache
      return unless church_id

      # After commit, possibly outside the tenant block that made the change: scope by church_id explicitly.
      ActsAsTenant.without_tenant { Site.where(church_id:).update_all("content_version = content_version + 1, updated_at = now()") }
    end
end
