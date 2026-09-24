# Demo data. Idempotent: re-running skips churches that exist.
# Grace Community Church: grace.localhost:3000  (admin@grace.test / password)
# Hope Fellowship:        hope.localhost:3000   (admin@hope.test / password)
# Platform console:       localhost:3000        (platform@stewardly.test / password)
# In production (a public demo, SEED_DEMO_DATA=1) the demo accounts use SEED_PASSWORD instead.
require "faker"

Faker::Config.random = Random.new(2026)
PASSWORD = if Rails.env.production?
  ENV["SEED_PASSWORD"].to_s.then do |password|
    abort "Set SEED_PASSWORD (12+ characters) to seed demo accounts in production." if password.length < 12 || password == "password"
    password
  end
else
  "password"
end

PlatformAdmin.find_or_create_by!(email_address: "platform@stewardly.test") do |admin|
  admin.name = "Platform Admin"
  admin.password = PASSWORD
end

# Streets around a real neighborhood so Phase 1 maps have believable points.
def seed_households(church, count:, center:, city:, region:, postal_codes:)
  geo = RGeo::Geographic.spherical_factory(srid: 4326)

  count.times do
    last_name = Faker::Name.unique.last_name
    household = Household.create!(
      name: "The #{last_name} household",
      address_line1: Faker::Address.street_address,
      city:, region:, postal_code: postal_codes.sample,
      location: geo.point(center[:lng] + rand(-0.08..0.08), center[:lat] + rand(-0.06..0.06))
    )

    adults = rand(1..2)
    adults.times do
      first_name = Faker::Name.first_name
      Person.create!(
        household:, first_name:, last_name:,
        email: Faker::Internet.unique.email(name: "#{first_name} #{last_name}", domain: "example.com"),
        phone: Faker::PhoneNumber.cell_phone,
        birthdate: Faker::Date.birthday(min_age: 24, max_age: 80),
        membership_status: %w[ member member member regular_attender guest inactive ].sample
      )
    end

    rand(0..3).times do
      Person.create!(
        household:, first_name: Faker::Name.first_name, last_name:, household_role: :child,
        birthdate: Faker::Date.birthday(min_age: 1, max_age: 17),
        membership_status: :regular_attender
      )
    end
  end
end

def seed_staff_user(role_key, first_name:, last_name:, email_address:)
  person = Person.create!(first_name:, last_name:, email: email_address, membership_status: :member)
  User.create!(person:, email_address:, password: PASSWORD, roles: [ Role.find_by!(key: role_key) ])
end

unless Church.exists?(subdomain: "grace")
  grace = Church::Provisioning.new(
    name: "Grace Community Church", subdomain: "grace", time_zone: "Central Time (US & Canada)",
    admin: { first_name: "Dana", last_name: "Whitfield", email_address: "admin@grace.test", password: PASSWORD }
  ).provision!

  ActsAsTenant.with_tenant(grace) do
    seed_staff_user "staff", first_name: "Marcus", last_name: "Bell", email_address: "staff@grace.test"
    seed_staff_user "care_team", first_name: "Priya", last_name: "Raman", email_address: "care@grace.test"
    seed_staff_user "member", first_name: "Tom", last_name: "Okafor", email_address: "member@grace.test"

    # Around Nashville, TN
    seed_households(grace, count: 45, center: { lat: 36.1627, lng: -86.7816 }, city: "Nashville", region: "TN",
      postal_codes: %w[ 37203 37204 37206 37208 37212 ])
  end
  puts "Seeded #{grace.name}: #{ActsAsTenant.with_tenant(grace) { Person.count }} people"
end

# Phase 1: organization, tags, custom fields, contact history, tasks, and prayer.
def seed_phase_one(church)
  return if Ministry.exists?

  Person.transaction { seed_phase_one!(church) }
end

def seed_phase_one!(church)
  admin = User.find_by!(email_address: "admin@#{church.subdomain}.test")
  people = Person.adult.to_a
  center = Household.located.pick(Arel.sql("avg(ST_Y(location::geometry))"), Arel.sql("avg(ST_X(location::geometry))")).map(&:to_f)

  Campus.default.update!(address_line1: "600 Church St", city: "Nashville", region: "TN", postal_code: "37219",
    location: Campus.point(latitude: center[0], longitude: center[1]), geocoded_at: Time.current)

  tags = %w[ Newcomer Volunteer Baptized Parent Musician ].zip(Tag::COLORS.cycle).map { |name, color| Tag.create!(name:, color:) }
  people.each { |person| person.tags << tags.sample(rand(0..2)) }

  shirt = CustomField.create!(label: "T-shirt size", field_type: "select", options: %w[ S M L XL ])
  CustomField.create!(label: "Allergies", field_type: "text")
  CustomField.create!(label: "Background check", field_type: "boolean")
  people.sample(30).each { |person| person.update!(custom_field_values: { shirt.key => shirt.options.sample }) }

  groups_ministry = Ministry.create!(name: "Groups", description: "Small groups and Bible studies")
  worship = Ministry.create!(name: "Worship", description: "Sunday services and music")
  hospitality = Ministry.create!(name: "Hospitality", description: "Greeters, coffee, and first impressions")
  MinistryLeadership.create!(ministry: worship, user: User.find_by!(email_address: "staff@#{church.subdomain}.test"))

  # Group meeting points spread around the city; a couple of neighborhoods are left uncovered.
  [ [ "Eastside Young Families", :small_group, 0.03, 0.04 ], [ "Downtown Bible Study", :bible_study, 0.0, 0.0 ],
    [ "West End Connect", :connection_group, -0.02, -0.05 ], [ "Tuesday Men's Study", :bible_study, 0.04, -0.01 ] ].each do |name, type, dlat, dlng|
    group = Group.create!(name:, group_type: type, ministry: groups_ministry, capacity: 12, meeting_day: rand(1..5),
      meeting_time: "19:00", address_line1: Faker::Address.street_address, city: "Nashville", region: "TN",
      location: Group.point(latitude: center[0] + dlat, longitude: center[1] + dlng), geocoded_at: Time.current)
    people.sample(rand(4..9)).each_with_index { |person, i| GroupMembership.create!(group:, person:, role: i.zero? ? :leader : :member) }
  end

  band = Team.create!(ministry: worship, name: "Worship band")
  %w[ Vocals Keys Drums Guitar Sound ].each { |name| band.positions.create!(name:) }
  greeters = Team.create!(ministry: hospitality, name: "Greeters")
  [ "Door", "Welcome desk", "Coffee" ].each { |name| greeters.positions.create!(name:) }
  people.sample(8).each { |person| band.team_memberships.create!(person:) }
  people.sample(10).each { |person| greeters.team_memberships.create!(person:) }

  people.sample(60).each do |person|
    rand(1..3).times do
      person.touchpoints.create!(kind: Touchpoint::MANUAL_KINDS.sample, author: admin, occurred_at: rand(1..120).days.ago,
        summary: [ "Coffee after service", "Checked in by phone", "Hospital visit", "Welcome note", "Texted about small groups" ].sample)
    end
  end

  launch = Project.create!(name: "Fall launch", description: "Everything for the fall ministry season")
  [ [ "Order new welcome packets", :todo, :high, launch ], [ "Recruit two more greeters", :in_progress, :normal, launch ],
    [ "Plan newcomer lunch", :todo, :urgent, nil ], [ "Paint the kids' wing", :idea, :low, nil ],
    [ "Start a young adults group", :idea, :normal, nil ], [ "Update the church directory", :done, :normal, nil ] ].each do |title, status, priority, project|
    Task.create!(title:, status:, priority:, project:, owner: admin, created_by: admin, due_on: church.today + rand(-5..20).days)
  end

  care = User.find_by!(email_address: "care@#{church.subdomain}.test")
  people.sample(5).each_with_index do |person, index|
    request = PrayerRequest.create!(person:, created_by: admin, visibility: index.even? ? :prayer_team : :pastoral_staff,
      body: [ "Upcoming surgery next week", "Job search", "Healing for my mother", "New baby on the way", "Wisdom for a big decision" ][index])
    request.prayer_assignments.create!(user: care) if index.even?
  end
end

# Phase 2: starter forms, published, with a few sample submissions.
def seed_phase_two
  return if Form.exists?

  Form.transaction do
    Form::Starters.install!
    Form.find_each(&:publish!)

    connect = Form.find_by!(slug: "connect")
    [
      { "first_name" => "Jamie", "last_name" => "Ortiz", "email" => "jamie.ortiz@example.com", "first_visit" => "1",
        "heard_about_us" => "A friend", "interests" => [ "Joining a group" ] },
      { "first_name" => "Priya", "last_name" => "Nair", "email" => "priya.nair@example.com", "phone" => "615-555-0142",
        "interests" => [ "Serving", "Baptism" ], "comments" => "We just moved to Nashville!" }
    ].each do |answers|
      submission = FormSubmission.build_from(connect, Form::Response.new(connect, answers))
      submission.save!
      FormSubmission::Processing.new(submission).process!
    end
  end
end

# Phase 3: services, schedules, events, courses, updates, and a member with things to do.
def seed_phase_three(church)
  return if WorshipService.exists?

  Person.transaction do
    church.update!(contact_email: "office@#{church.subdomain}.test", giving_url: "https://tithe.ly/give?c=demo")
    admin = User.find_by!(email_address: "admin@#{church.subdomain}.test")
    member = User.find_by!(email_address: "member@#{church.subdomain}.test").person
    campus = Campus.default

    services = [ [ "Sunday 9am", "09:00" ], [ "Sunday 11am", "11:00" ] ].map do |name, time|
      WorshipService.create!(name:, day_of_week: 0, start_time: time, duration_minutes: 75, campus:)
    end

    band = Team.find_by!(name: "Worship band")
    greeters = Team.find_by!(name: "Greeters")
    [ band, greeters ].each { |team| team.team_memberships.find_or_create_by!(person: member) }
    needs = { band => { "Vocals" => 2, "Keys" => 1, "Drums" => 1, "Sound" => 1 }, greeters => { "Door" => 2, "Welcome desk" => 1, "Coffee" => 1 } }
    services.each do |service|
      needs.each { |team, positions| positions.each { |name, quantity| service.position_needs.create!(position: team.positions.find_by!(name:), quantity:) } }
    end

    # Only some of the band can play drums or run sound.
    band.team_memberships.first(3).each do |membership|
      %w[ Drums Sound ].each { |name| PositionQualification.create!(position: band.positions.find_by!(name:), person: membership.person) }
    end
    band.team_memberships.second&.update!(max_per_month: 2)
    Blockout.create!(person: greeters.team_memberships.first.person, starts_on: church.today + 7, ends_on: church.today + 14, reason: "Vacation")

    range = church.today.beginning_of_week(:sunday)..(church.today.beginning_of_week(:sunday) + 5.weeks - 1.day)
    [ band, greeters ].each { |team| Scheduling::AutoFill.new(team:, range:, assigned_by: admin).fill! }
    Assignment.where(local_date: range.first..(range.first + 13)).find_each do |assignment|
      assignment.update!(requested_at: 3.days.ago, status: assignment.id.even? ? "accepted" : "pending", responded_at: (1.day.ago if assignment.id.even?))
    end
    next_sunday = church.today.next_occurring(:sunday)
    occurrence = services.first.occurrences.find_by(local_date: next_sunday)
    occurrence.assignments.find_or_create_by!(position: greeters.positions.find_by!(name: "Coffee"), person: member) { |a| a.assigned_by = admin; a.requested_at = Time.current } if occurrence

    lunch_form = Form.create!(name: "Newcomer lunch questions", purpose: "event_registration")
    lunch_form.fields.create!(key: "dietary", label: "Any dietary needs?", field_type: "text")
    lunch_form.fields.create!(key: "childcare", label: "We'd like childcare", field_type: "checkbox")
    lunch_form.fields.create!(key: "children", label: "How many children?", field_type: "number",
      visibility_rule: { conditions: [ { field: "childcare", operator: "filled" } ] })
    lunch_form.publish!

    hospitality = Ministry.find_by!(name: "Hospitality")
    lunch = Event.create!(title: "Newcomer lunch", ministry: hospitality, campus:, location_name: "Fellowship hall", organizer: admin,
      description: "Meet our pastors and hear what Grace is all about. Lunch is on us!", registration_required: true, capacity: 12,
      max_party_size: 4, registration_form: lunch_form, visibility: "public", status: "published")
    at = ->(date, hour, minute = 0) { church.zone.local(date.year, date.month, date.day, hour, minute) }
    starts = at.(next_sunday + 7, 12, 30)
    lunch.occurrences.create!(starts_at: starts, ends_at: starts + 90.minutes)
    lunch.position_needs.create!(position: greeters.positions.find_by!(name: "Welcome desk"), quantity: 1)

    picnic = Event.create!(title: "Fall picnic", ministry: hospitality, location_name: "Shelby Park", address_line1: "401 S 20th St", city: "Nashville",
      description: "Bring a blanket and a side dish.", registration_required: true, max_party_size: 8, visibility: "members", status: "published", organizer: admin)
    picnic_day = church.today + 20
    picnic.occurrences.create!(starts_at: at.(picnic_day, 16), ends_at: at.(picnic_day, 19))

    Person.unmerged.adult.where.not(email: nil).limit(9).each_with_index do |person, index|
      Registration::Booking.new(occurrence: lunch.occurrences.first, person:, party_size: [ 1, 2 ][index % 2]).book!
    end

    course = Course.create!(name: "Membership 101", description: "Our story, what we believe, and how to get involved. Four weeks.",
      ministry: Ministry.find_by!(name: "Groups"))
    offering = course.offerings.create!(starts_on: next_sunday, ends_on: next_sunday + 21, leader: admin.person, location_name: "Room 204", capacity: 15)
    [ "Our story", "What we believe", "Belonging", "Serving and next steps" ].each_with_index do |topic, index|
      starts_at = at.(next_sunday + (index * 7), 12, 15)
      offering.sessions.create!(starts_at:, ends_at: starts_at + 75.minutes, topic:)
    end
    Person.unmerged.guest.adult.limit(5).each { |person| Enrollment::Booking.new(offering:, person:).book! }

    Announcement.create!(title: "Fall kickoff Sunday", body: "One service at 10am on the first Sunday of the season, then lunch on the lawn.",
      published_at: 2.days.ago, pinned: true, author: admin)
    Announcement.create!(title: "Serve on a team", body: "Greeters and the worship band are looking for a few more people. Ask at the welcome desk!",
      published_at: 1.day.ago, author: admin)

    group = Group.active.first
    GroupJoinRequest.create!(group:, person: Person.unmerged.adult.where.not(id: group.people.select(:id)).first, message: "We're new and would love to join!")
    PrayerRequest.create!(person: member, body: "For our neighbors who just moved in", visibility: "shared", created_by: admin)
  end
end

# Phase 4: 2½ years of made-up but realistic Sunday counts (growth, a summer dip,
# holiday effects, noise), then forecasts made week by week as if in real time.
def seed_phase_four(church)
  return if AttendanceCount.exists?

  random = Random.new(44)
  special_days = Attendance::SpecialDays.new(church)
  effects = { "easter" => 1.65, "palm_sunday" => 1.08, "christmas" => 1.35, "new_years" => 0.78, "mothers_day" => 1.18,
    "fathers_day" => 0.96, "memorial_day_weekend" => 0.84, "independence_day_weekend" => 0.82, "labor_day_weekend" => 0.87,
    "thanksgiving_weekend" => 0.9, "church:back-to-school" => 1.12 }
  start = (church.today - 130.weeks).beginning_of_week(:sunday)
  last_sunday = church.today.sunday? ? church.today - 7 : church.today.beginning_of_week(:sunday)

  AttendanceCount.transaction do
    (start.year..church.today.year).each do |year|
      back_to_school = Date.new(year, 8, 1).next_occurring(:sunday) + 14
      SpecialSunday.find_or_create_by!(local_date: back_to_school) { |day| day.name = "Back to school" }
    end

    { "Sunday 9am" => 170, "Sunday 11am" => 235 }.each do |name, base|
      service = WorshipService.find_by!(name:)
      service.ensure_occurrences!(start..last_sunday)
      service.occurrences.where(local_date: start..last_sunday).order(:local_date).each do |occurrence|
        date = occurrence.local_date
        years = (date - start) / 365.0
        expected = base * (1.07**years) * (date.month.in?([ 6, 7, 8 ]) ? 0.9 : 1.0)
        special_days.for(date).each { |day| expected *= effects.fetch(day.key, 1.0) }
        total = (expected * (1 + random.rand(-0.06..0.06))).round
        online = (total * (0.22 + random.rand(-0.03..0.03))).round
        kids = ((total - online) * 0.22).round
        occurrence.create_attendance_count!(breakdown: { "Adults" => total - online - kids, "Kids" => kids, "Online" => online },
          first_time_guests: random.rand(1..7) + (special_days.special?(date) ? 4 : 0))
      end

      # Forecast the last 26 weeks as if each was made the night before, then freeze them.
      forecaster = Attendance::Forecaster.new(service)
      service.occurrences.where(local_date: (last_sunday - 25.weeks)..last_sunday).order(:local_date).each do |occurrence|
        result = forecaster.forecast(occurrence.local_date)
        next unless result.enough?

        occurrence.create_forecast!(expected: result.expected, low: result.low, high: result.high, expected_online: result.expected_online,
          factors: result.factors.map(&:to_h), model_version: AttendanceForecast::MODEL_VERSION,
          generated_at: occurrence.starts_at - 1.day, frozen_at: occurrence.starts_at)
      end
    end

    # A few individual check-ins last Sunday.
    occurrence = ServiceOccurrence.find_by(local_date: last_sunday)
    Person.unmerged.adult.limit(12).each { |person| occurrence.attendances.create!(person:) } if occurrence
  end

  ForecastSweepJob.new.send(:sweep, church)
end

# Phase 5: pathway placements with a backdated history (so the funnel has movement),
# and a few volunteers who serve a lot, or not at all.
def seed_phase_five(church)
  return if PathwayPlacement.exists?

  random = Random.new(55)
  pathway = Pathway.current
  connect, grow, serve = pathway.stages.to_a
  now = Time.current

  PathwayPlacement.transaction do
    # Team members joined months ago, so "underused" can apply.
    TeamMembership.update_all(created_at: 6.months.ago)

    # A couple of volunteers serving every week for two months.
    band = Team.find_by!(name: "Worship band")
    ServiceOccurrence.where(local_date: (church.today - 63)...church.today).includes(:worship_service)
      .select { |o| o.worship_service.name == "Sunday 9am" }.each do |occurrence|
      band.team_memberships.first(2).each do |membership|
        occurrence.assignments.find_or_create_by!(person: membership.person, position: band.positions.find_by!(name: "Vocals")) do |a|
          a.status = "accepted"
          a.requested_at = occurrence.starts_at - 7.days
          a.responded_at = occurrence.starts_at - 6.days
        end
      end
    end

    Pathway::Placement.new(pathway).place_everyone!

    # Replace today's first placements with a believable past.
    PathwayTransition.delete_all
    PathwayPlacement.includes(:pathway_stage).find_each do |placement|
      started = now - random.rand(60..480).days
      steps = [ [ nil, connect, :placed, started ] ]
      if placement.pathway_stage_id.in?([ grow.id, serve.id ])
        steps << [ connect, grow, :forward, [ started + random.rand(20..120).days, now - 5.days ].min ]
      end
      if placement.pathway_stage_id == serve.id
        steps << [ grow, serve, :forward, [ steps.last.last + random.rand(30..150).days, now - 2.days ].min ]
      end
      steps.each do |from, to, direction, at|
        PathwayTransition.create!(person_id: placement.person_id, from_stage: from, to_stage: to, direction:, occurred_at: at)
      end
      placement.update!(entered_at: steps.last.last)
    end
  end
end

# Phase 6: topics, starter templates, a draft campaign, and one sent campaign with
# made-up delivery results (written directly; seeds never send email).
def seed_phase_six(church)
  church.update!(mailing_address: "412 Grace Ave\nSpringfield, IL 62704") if church.mailing_address.blank?
  news = EmailTopic.default!
  kids = EmailTopic.find_or_create_by!(name: "Kids ministry") { |t| t.description = "Sunday school, VBS, and family events."; t.default_subscribed = false }
  SectionDefinition::Defaults.install!
  EmailTemplate::Starters.install!
  return if Campaign.exists?

  newsletter = EmailTemplate.find_by!(name: "Weekly newsletter")
  everyone = Segment.find_or_create_by!(name: "Everyone with email") { |s| s.definition = { match: "all", conditions: [] } }
  people = Person.where.not(email: nil).order(:id).to_a
  people.first(4).each { |person| EmailPreference.find_or_create_by!(person:, email_topic: kids) { |p| p.subscribed = true } }
  Suppression.record!(people.last.email, reason: :hard_bounce, source: "bounce") if people.any?

  Campaign.create!(name: "Fall kickoff", subject: "{{ person.first_name }}, fall starts Sunday", email_template: newsletter,
    segment: everyone, email_topic: news, track_engagement: true)

  sent_at = 9.days.ago.change(hour: 7)
  sent = Campaign.create!(name: "Summer wrap-up", subject: "Thank you for a great summer", email_template: newsletter, segment: everyone,
    email_topic: news, status: :sent, sending_at: sent_at, sent_at: sent_at + 4.minutes,
    html_snapshot: EmailTemplate::Renderer.new(newsletter).compile(tracking: Email::Tracking.new(church)))
  random = Random.new(6)
  people.first(people.size - 1).each do |person|
    roll = random.rand
    status = roll < 0.03 ? "bounced" : "delivered"
    opened = status == "delivered" && roll < 0.62
    clicked = opened && roll < 0.18
    Delivery.create!(campaign: sent, person:, email: person.email, status:, sent_at: sent_at + 1.minute, provider_message_id: SecureRandom.uuid,
      delivered_at: (sent_at + 2.minutes if status == "delivered"), first_opened_at: (sent_at + random.rand(1..72).hours if opened),
      open_count: opened ? random.rand(1..3) : 0, first_clicked_at: (sent_at + random.rand(2..80).hours if clicked), click_count: clicked ? 1 : 0,
      unsubscribed_at: (sent_at + 1.day if roll > 0.985))
  end
end

# Phase 7: the starter workflows, two published (with staff chosen for tasks and alerts),
# and a few people part-way through them. Jobs are held (test adapter) and steps driven
# here, so seeding works without Sidekiq; waits are left waiting. AI stays off, so the
# guest thank-you notes sit in the approval queue for someone to write.
def seed_phase_seven(church)
  Workflow::Starters.install!
  return if WorkflowRun.exists?

  admin = User.find_by!(email_address: "admin@grace.test")
  previous_adapter = ActiveJob::Base.queue_adapter
  ActiveJob::Base.queue_adapter = :test

  %w[ new_member_welcome first_time_guest ].each do |key|
    workflow = Workflow.find_by!(starter_key: key)
    workflow.draft.all_steps.each do |step|
      case step["type"]
      when "create_task" then workflow.update_step!(step["id"], step["config"].merge("owner_id" => admin.id))
      when "notify_staff" then workflow.update_step!(step["id"], step["config"].merge("user_ids" => [ admin.id ]))
      end
    end
    workflow.publish!(by: admin)
  end

  drive = lambda do |run|
    20.times do
      run.reload
      break unless run.active? && run.current_step_id

      Workflow::Execution.new(run).perform(run.current_step_id)
    end
  end

  welcome = Workflow.find_by!(starter_key: "new_member_welcome")
  new_member = Tag.find_by!(name: "New member")
  Person.where(membership_status: "member").where.not(email: nil).order(:id).limit(2).each do |person|
    Tagging.find_or_create_by!(person:, tag: new_member)
    Workflow::Enrollment.new(welcome, person).start!&.then(&drive)
  end

  guest_follow_up = Workflow.find_by!(starter_key: "first_time_guest")
  Person.where(membership_status: "guest").where.not(email: nil).order(:id).limit(3).each do |person|
    Workflow::Enrollment.new(guest_follow_up, person).start!&.then(&drive)
  end
ensure
  ActiveJob::Base.queue_adapter = previous_adapter if previous_adapter
end

# Phase 8: a year of made-up giving (provider "demo", since nothing is synced from
# Tithe.ly yet) with a few gifts waiting in the review queue, and benevolence cases in
# every state. Priya (care@grace.test) is on the Benevolence team.
def seed_phase_eight(church)
  Form::Starters.install!
  return if Donation.exists?

  priya = User.find_by!(email_address: "care@grace.test")
  UserRole.find_or_create_by!(user: priya, role: Role.find_by!(key: "benevolence_team"))
  admin = User.find_by!(email_address: "admin@grace.test")

  random = Random.new(8)
  funds = { "General" => 0.8, "Missions" => 0.15, "Building" => 0.05 }.map { |name, share| [ Fund.find_or_create_by!(name:, provider: "demo", external_id: name.downcase), share ] }
  givers = Person.where.not(email: nil).order(:id).limit(35).to_a
  today = church.today
  sequence = 0
  givers.each_with_index do |person, index|
    usual = [ 25, 40, 50, 75, 100, 150, 250 ].sample(random: random) * 100
    link_id = "demo-donor-#{person.id}"
    DonorLink.find_or_create_by!(provider: "demo", donor_external_id: link_id) { |link| link.person = person } unless index > 30
    (0..51).step(index.even? ? 1 : 2) do |weeks_ago|
      next if random.rand < 0.15

      fund = funds.find { |_, share| random.rand < share }&.first || funds.first.first
      Donation.create!(provider: "demo", external_id: "demo-#{sequence += 1}", donor_external_id: link_id, donor_name: person.name,
        donor_email: person.email, fund:, amount_cents: usual, given_on: today - weeks_ago.weeks, method: %w[ card ach ].sample(random:),
        person: index > 30 ? nil : person, match_status: index > 30 ? "unmatched" : "auto", matched_at: Time.current)
    end
  end
  Donation.where(external_id: "demo-3").update_all(status: "refunded")

  care = Fund.find_or_create_by!(name: "Care fund", provider: "manual") { |fund| fund.benevolence = true }
  people = Person.where.not(household_id: nil).order(:id).offset(10).limit(5).to_a
  create_case = lambda do |person, attributes|
    BenevolenceCase.create!({ person:, created_by: priya, assigned_to: priya, source: "staff" }.merge(attributes))
  end

  create_case.(people[0], need_category: "rent", summary: "Two weeks behind on rent", circumstances: "Reduced hours after an injury.", requested_cents: 45_000)
  create_case.(people[1], need_category: "food", summary: "Groceries until payday", requested_cents: 12_000, source: "form")
  large = create_case.(people[2], need_category: "utilities", summary: "Winter heating bill", circumstances: "Gas shut-off notice received.",
    requested_cents: 80_000, created_at: 2.days.ago)
  large.decision.record!(user: admin, decision: "approve", amount_cents: 60_000, note: "Approve most of it; connect them with the county program.")
  large.notes.create!(author: priya, body: "Called the gas company: they'll hold the shut-off for a week once payment is scheduled.")

  paid = create_case.(people[3], need_category: "transportation", summary: "Car repair to get to work", requested_cents: 35_000, created_at: 3.months.ago)
  paid.decision.record!(user: admin, decision: "approve", amount_cents: 35_000)
  paid.disbursements.create!(amount_cents: 35_000, paid_on: today - 80, method: "check", payee_type: "vendor", payee_name: "Main Street Auto",
    fund: care, reference: "Check 2201", recorded_by: priya)

  denied = create_case.(people[4], need_category: "other", summary: "Help with a phone bill", requested_cents: 9_000, created_at: 1.month.ago)
  denied.decision.record!(user: admin, decision: "deny", note: "Referred to the community resource center.")
end

# Phase 9: run the insight checks, build the admin's brief (rules, since AI is off by
# default), and pin a couple of reports to their dashboard.
def seed_phase_nine(church)
  admin = User.find_by!(email_address: "admin@grace.test")
  Insights::Sweep.new(church).run!
  Insights::Brief.new(admin).build!
  return if SavedReport.exists?

  [ [ "New people and groups this year", "group_connection" ], [ "Volunteer coverage, next 4 weeks", "volunteer_coverage" ] ].each do |title, tool|
    SavedReport.create!(user: admin, title:, pinned: true, tool_calls: [ { "name" => tool, "arguments" => {} } ]).rerun!
  end
end

# Phase 10: the website, live at grace.<sites_domain>, with the connect card on the
# contact page and a few sermons.
def seed_phase_ten(church)
  site = Site.current
  return if site.published?

  Form.find_by(slug: "connect")&.then { |form| form.publish! unless form.published? }
  site.update!(theme_settings: { "tagline" => "Love God, love people, serve the city", "footer_text" => "412 Grace Ave, Springfield, IL\nSundays at 9 and 10:45" })
  about = site.pages.find_by!(slug: "about")
  staff = about.section_list.find { |section| section["key"] == "staff" }
  about.update_section!(staff["id"], staff["settings"].merge("blocks" => [
    { "name" => "Caleb Woods", "role" => "Lead pastor" }, { "name" => "Priya Raman", "role" => "Care pastor" },
    { "name" => "Sam Ortiz", "role" => "Worship and arts" }
  ]))
  home = site.home_page
  sermons = home.add_section!("sermon_links", after: home.section_list.find { |section| section["key"] == "upcoming_events" }&.dig("id"))
  home.update_section!(sermons["id"], sermons["settings"].merge("blocks" => [
    { "title" => "The God who sees", "speaker" => "Caleb Woods", "date" => "September 20", "url" => "https://www.youtube.com/watch?v=dQw4w9WgXcQ" },
    { "title" => "Bread for the journey", "speaker" => "Priya Raman", "date" => "September 13", "url" => "" }
  ]))
  site.pages.each(&:publish!)
  site.update!(published: true, published_at: Time.current)
end

# Phase 11: demo Facebook and Instagram accounts (fake tokens: nothing can really be
# posted without a Meta app), one post that "went out", a draft, and an event promo draft.
# Nothing is scheduled, so the sweeper never tries to reach Meta from seed data.
def seed_phase_eleven(church)
  return if SocialAccount.exists?

  integration = Integration.create!(category: "social", provider: "meta", credentials: { "user_access_token" => "demo" }, settings: { "meta_user_id" => "demo" })
  facebook = SocialAccount.create!(integration:, network: "facebook_page", external_id: "demo-page", name: "Grace Community Church", access_token: "demo", checked_at: Time.current)
  SocialAccount.create!(integration:, network: "instagram", external_id: "demo-ig", name: "gracechurch", handle: "gracechurch", access_token: "demo", checked_at: Time.current)

  published = SocialPost.new(body: "Thank you to everyone who served at the back-to-school drive! 🎒 240 backpacks packed.", status: "published",
    published_at: 3.days.ago, scheduled_at: 3.days.ago)
  published.account_ids = [ facebook.id ]
  published.save!
  published.targets.update_all(status: "published", external_post_id: "demo", permalink: "https://www.facebook.com/", published_at: 3.days.ago)

  draft = SocialPost.new(body: "This Sunday we're starting a new series on the Psalms. Come as you are.")
  draft.account_ids = SocialAccount.ids
  draft.save!

  Event.published.where(visibility: "public").find_each { |event| Social::EventPromo.new(event).draft!(force: true) }
end

if (grace = Church.find_by(subdomain: "grace"))
  ActsAsTenant.with_tenant(grace) do
    seed_phase_one(grace)
    seed_phase_two
    seed_phase_three(grace)
    seed_phase_four(grace)
    seed_phase_five(grace)
    seed_phase_six(grace)
    seed_phase_seven(grace)
    seed_phase_eight(grace)
    seed_phase_nine(grace)
    seed_phase_ten(grace)
    seed_phase_eleven(grace)
  end
end

unless Church.exists?(subdomain: "hope")
  hope = Church::Provisioning.new(
    name: "Hope Fellowship", subdomain: "hope", time_zone: "Mountain Time (US & Canada)",
    admin: { first_name: "Ruth", last_name: "Castillo", email_address: "admin@hope.test", password: PASSWORD }
  ).provision!

  ActsAsTenant.with_tenant(hope) do
    # Around Denver, CO
    seed_households(hope, count: 6, center: { lat: 39.7392, lng: -104.9903 }, city: "Denver", region: "CO",
      postal_codes: %w[ 80203 80205 80218 ])
  end
  puts "Seeded #{hope.name}: #{ActsAsTenant.with_tenant(hope) { Person.count }} people"
end
