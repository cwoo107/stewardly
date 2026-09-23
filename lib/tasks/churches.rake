namespace :churches do
  desc "Create a church with default roles and a first admin. " \
       "NAME= SUBDOMAIN= TIME_ZONE= ADMIN_FIRST_NAME= ADMIN_LAST_NAME= ADMIN_EMAIL= ADMIN_PASSWORD="
  task create: :environment do
    church = Church::Provisioning.new(
      name: ENV.fetch("NAME"), subdomain: ENV.fetch("SUBDOMAIN"), time_zone: ENV.fetch("TIME_ZONE", "Central Time (US & Canada)"),
      admin: {
        first_name: ENV.fetch("ADMIN_FIRST_NAME"), last_name: ENV.fetch("ADMIN_LAST_NAME"),
        email_address: ENV.fetch("ADMIN_EMAIL"), password: ENV.fetch("ADMIN_PASSWORD")
      }
    ).provision!
    puts "Created #{church.name} at #{church.host}"
  end
end

namespace :platform_admins do
  desc "Create a platform admin. NAME= EMAIL= PASSWORD="
  task create: :environment do
    admin = PlatformAdmin.create!(name: ENV.fetch("NAME"), email_address: ENV.fetch("EMAIL"), password: ENV.fetch("PASSWORD"))
    puts "Created platform admin #{admin.email_address}"
  end
end
