# Querying a tenant-scoped model without a current church raises
# ActsAsTenant::Errors::NoTenantSet. Cross-tenant code (platform console,
# provisioning, seeds) must opt out explicitly with ActsAsTenant.without_tenant
# or pick a church with ActsAsTenant.with_tenant.
#
# Active Job: acts_as_tenant serializes the current tenant into every job
# (including mailer deliveries) and restores it before arguments are deserialized.
ActsAsTenant.configure do |config|
  config.require_tenant = true
end
