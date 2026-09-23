# The fixed catalogue of permissions a Role can grant. Keys live in code so
# policies can reference them safely; roles store the keys they grant.
module Permission
  ALL = {
    "manage_church_settings" => "Edit church name, time zone, campuses, and other settings",
    "manage_users" => "Manage user accounts and grant or revoke roles",
    "view_audit_log" => "View the audit log",
    "view_people" => "See people, households, groups, teams, and the map",
    "manage_people" => "Create, edit, import, tag, and merge people and households",
    "view_precise_locations" => "See exact home locations instead of approximate ones",
    "manage_ministries" => "Manage every ministry and its groups and teams (leaders manage only their own)",
    "manage_tasks" => "See and manage every task and project",
    "manage_forms" => "Build, publish, and close forms",
    "manage_email" => "Build email templates, send campaigns, and see their reports",
    "manage_workflows" => "Build, publish, and pause workflows, and see their runs",
    "approve_messages" => "Review, edit, and send messages workflows drafted (including AI drafts)",
    "view_giving" => "See donations, giving totals, and each person's giving",
    "manage_giving" => "Match donations to people and manage funds",
    "view_benevolence" => "See benevolence cases and their history (every view is logged)",
    "manage_benevolence" => "Open benevolence cases, add notes, and record payments",
    "approve_benevolence" => "Approve or deny benevolence requests",
    "view_insights" => "See insights (things that need attention) and a daily brief",
    "use_reports" => "Ask the report assistant questions and run metrics",
    "manage_website" => "Edit and publish the church website's pages and theme",
    "develop_website" => "Edit website code (section Liquid, the theme layout), custom sections, and domains",
    "manage_social" => "Write, schedule, and publish social media posts",
    "manage_integrations" => "Connect outside services (email provider, Mailchimp) and see their credentials",
    "manage_schedules" => "Build every team's volunteer schedule and set up worship services (leaders schedule their own teams)",
    "manage_events" => "Create and run every event, its registrations, and check-in (leaders run their ministry's events)",
    "manage_courses" => "Run every course, its enrollments, and attendance (leaders run their ministry's courses)",
    "manage_announcements" => "Post church updates to the member area",
    "manage_pathways" => "Set up the discipleship pathway's stages and rules, and volunteer load thresholds",
    "record_attendance" => "Enter Sunday headcounts, check people in, and mark special Sundays",
    "view_attendance" => "See attendance, forecasts, and growth",
    "view_form_submissions" => "See and export form submissions (prayer forms need prayer permissions)",
    "view_prayer_requests" => "See prayer requests shared with the prayer team, and ones assigned to you",
    "manage_prayer_requests" => "See and manage every prayer request, including pastoral-only ones"
  }.freeze

  class UnknownPermission < ArgumentError; end

  def self.keys = ALL.keys

  def self.description(key) = ALL.fetch(key.to_s)

  def self.fetch(key)
    key = key.to_s
    raise UnknownPermission, "Unknown permission: #{key}" unless ALL.key?(key)
    key
  end
end
