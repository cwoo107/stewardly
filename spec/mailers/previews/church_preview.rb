# Shared by the previews: run inside the demo church (bin/rails db:seed). Mailer calls
# return a lazy MessageDelivery, so the message is built here, while the church is set.
module ChurchPreview
  def church = ActsAsTenant.without_tenant { Church.find_by(subdomain: "grace") || Church.first }

  def within_church
    ActsAsTenant.with_tenant(church) do
      result = yield
      result.respond_to?(:message) ? result.message : result
    end
  end
end
