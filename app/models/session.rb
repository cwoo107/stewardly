class Session < ApplicationRecord
  belongs_to :user
  # Tenant-scoped so a session cookie only resolves on its own church's subdomain.
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church
end
