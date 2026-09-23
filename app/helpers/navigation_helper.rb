# The admin sidebar: a few top links, then collapsible sections. The section holding
# the current page is open; the rest remember what the person last chose (nav_sections_controller.js).
module NavigationHelper
  NavLink = Data.define(:label, :path)
  NavSection = Data.define(:key, :heading, :links, :active)

  def navigation_top_links
    @navigation_top_links ||= visible([
      [ "Dashboard", root_path, policy(:dashboard).show? ],
      [ "Insights", insights_path, policy(Insight).index? ],
      [ "Calendar", calendar_path, policy(:calendar).show? ]
    ])
  end

  def navigation_sections
    @navigation_sections ||= navigation_definition.filter_map do |heading, links|
      links = visible(links)
      next if links.empty?

      NavSection.new(key: heading.parameterize, heading:, links:, active: links.any? { |link| link.path == active_nav_path })
    end
  end

  def nav_link_class(path)
    "block rounded-lg px-3 py-2 text-sm #{path == active_nav_path ? "bg-gray-100 font-semibold text-gray-900" : "text-gray-700 hover:bg-gray-50"}"
  end

  private
    def navigation_definition
      # From caring for people, through running the church, to the technical tools.
      @navigation_definition ||= [
        [ "People", [
          [ "People", people_path, policy(Person).index? ],
          [ "Households", households_path, policy(Household).index? ],
          [ "Segments", segments_path, policy(Segment).index? ],
          [ "Pathway", pathway_path, policy(Pathway).show? ],
          [ "Map", map_path, policy(:map).show? ]
        ] ],
        [ "Care & work", [
          [ "Prayer requests", prayer_requests_path, policy(PrayerRequest).index? ],
          [ "Benevolence", benevolence_cases_path, policy(BenevolenceCase).index? ],
          [ "Forms", forms_path, policy(Form).index? ],
          [ "Tasks", tasks_path, policy(Task).index? ]
        ] ],
        [ "Organization", [
          [ "Ministries", ministries_path, policy(Ministry).index? ],
          [ "Groups", groups_path, policy(Group).index? ]
        ] ],
        [ "Serving & events", [
          [ "Services", worship_services_path, policy(WorshipService).index? ],
          [ "Volunteer load", volunteer_load_path, policy(:volunteer_load).show? ],
          [ "Events", events_path, policy(Event).index? ],
          [ "Courses", courses_path, policy(Course).index? ],
          [ "Updates", announcements_path, policy(Announcement).index? ]
        ] ],
        [ "Attendance", [
          [ "Dashboard", attendance_path, policy(:attendance).show? ],
          [ "Enter counts", attendance_counts_path, policy(:attendance).record? ],
          [ "Special Sundays", special_sundays_path, policy(SpecialSunday).index? ]
        ] ],
        [ "Giving", [
          [ "Giving", giving_path, policy(Donation).index? ],
          [ "Review queue", donation_matches_path, policy(Donation).match? ],
          [ "Funds", funds_path, policy(Fund).index? ],
          [ "Giving settings", giving_settings_path, policy(:giving_settings).show? ]
        ] ],
        [ "Email", [
          [ "Campaigns", campaigns_path, policy(Campaign).index? ],
          [ "Templates", email_templates_path, policy(EmailTemplate).index? ],
          [ "Email settings", email_settings_path, policy(:email_settings).show? ],
          # Development only: every email rendered with sample data, and the mail actually "sent".
          [ "Email previews", "/rails/mailers", Rails.env.development? ],
          [ "Sent mail (dev)", "/letter_opener", Rails.env.development? ]
        ] ],
        [ "Social", [
          [ "Posts", social_posts_path, policy(SocialPost).index? ],
          [ "Content calendar", social_calendar_path, policy(SocialPost).index? ],
          [ "Accounts", social_accounts_path, policy(SocialAccount).index? ]
        ] ],
        [ "Website", [
          [ "Website", website_path, policy(:website).show? ],
          [ "Theme", edit_website_theme_path, policy(:website).update? ],
          [ "Code", website_sections_path, policy(:website).develop? ]
        ] ],
        [ "Automation", [
          [ "Workflows", workflows_path, policy(Workflow).index? ],
          [ approvals_label, message_drafts_path, policy(MessageDraft).index? ]
        ] ],
        [ "Reports", [
          [ "Ask", report_conversations_path, policy(:report).index? ],
          [ "Metrics", metrics_path, policy(:report).index? ],
          [ "Saved reports", saved_reports_path, policy(:report).index? ]
        ] ],
        [ "Admin", [
          [ "Users", users_path, policy(User).index? ],
          [ "Roles", roles_path, policy(Role).index? ],
          [ "Audit log", audit_events_path, policy(AuditEvent).index? ],
          [ "Settings", edit_church_settings_path, policy(Current.church).edit? ]
        ] ]
      ]
    end

    def approvals_label
      return "Approvals" unless policy(MessageDraft).index?

      count = MessageDraft.pending.count
      count.positive? ? "Approvals (#{count})" : "Approvals"
    end

    def visible(links)
      links.select(&:last).map { |label, path, _| NavLink.new(label:, path:) }
    end


    # The single link for the current page: an exact match, or the longest link the
    # path sits under ("Enter counts" on /attendance/counts, not the Attendance dashboard).
    def active_nav_path
      @active_nav_path ||= begin
        paths = navigation_top_links.map(&:path) + navigation_definition.flat_map { |_, links| visible(links).map(&:path) }
        paths.select { |path| request.path == path || (path != root_path && request.path.start_with?("#{path}/")) }.max_by(&:length)
      end
    end
end
