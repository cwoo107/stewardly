class Current < ActiveSupport::CurrentAttributes
  attribute :church, :site, :session, :platform_session, :ip_address
  delegate :user, to: :session, allow_nil: true
  delegate :platform_admin, to: :platform_session, allow_nil: true
end
