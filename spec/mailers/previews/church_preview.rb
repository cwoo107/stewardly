# Shared by the previews: run inside the demo church (bin/rails db:seed).
module ChurchPreview
  def church = ActsAsTenant.without_tenant { Church.find_by(subdomain: "grace") || Church.first }

  def within_church(&) = ActsAsTenant.with_tenant(church, &)
end
