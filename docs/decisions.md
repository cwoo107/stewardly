# Decisions

Short entries: decision, alternatives, reason. Newest at the bottom.

## 0.1 Sidekiq and Redis instead of the Solid suite
- **Decision:** Sidekiq for Active Job, Redis for the cache store and Action Cable.
- **Alternatives:** Solid Queue / Solid Cache / Solid Cable.
- **Reason:** Project standard. Two Redis instances: `REDIS_URL` for jobs and Action Cable (`noeviction`), `REDIS_CACHE_URL` for the cache (`allkeys-lru`), so cache pressure can never evict queued jobs.

## 0.2 `geography(Point, 4326)` for locations
- **Decision:** Spatial columns on lat/lng data are `geography`, SRID 4326, with a GiST index.
- **Alternatives:** `geometry` with a projected SRID.
- **Reason:** The questions we ask ("groups within 3 miles", nearest group) need true distances in meters, and `ST_DWithin` and KNN `<->` both work on geography. Switch to geometry only if we need a function geography lacks.

## 0.3 Row-level tenancy with `acts_as_tenant`, and `require_tenant = true`
- **Decision:** Every church-owned table has a non-null, indexed `church_id`. Querying a tenant model with no current church raises.
- **Alternatives:** Schema-per-tenant (Apartment), or opt-in scoping.
- **Reason:** One schema is simpler to migrate and report on. Raising on a missing tenant turns a forgotten scope into a loud error instead of a data leak. Cross-tenant code (platform console, provisioning, seeds) must say so with `ActsAsTenant.without_tenant` / `with_tenant`.
- **Note:** `acts_as_tenant` is declared *after* `belongs_to` associations so it also checks that each association belongs to the same church.

## 0.4 Jobs inherit the enqueuing church automatically
- **Decision:** Rely on acts_as_tenant's Active Job extension, which serializes the current church into every job (mailer deliveries included) and restores it before arguments are deserialized.
- **Alternatives:** Pass the church explicitly to every job and wrap `perform` in `with_tenant`.
- **Reason:** It can't be forgotten, and it also covers `deliver_later`. Jobs enqueued outside any church (sidekiq-cron sweeps, later phases) must iterate churches and call `ActsAsTenant.with_tenant` themselves.

## 0.5 Users belong to one church; email is unique per church
- **Decision:** `users.church_id` with a unique index on `[church_id, email_address]`. Sessions are also tenant-scoped.
- **Alternatives:** Global user identities with memberships in many churches.
- **Reason:** A User is linked to exactly one Person, and a Person belongs to one church. The same email can have separate accounts at two churches. A session cookie only resolves on its own church's subdomain.

## 0.6 Platform admins are a separate model
- **Decision:** `PlatformAdmin` and `PlatformSession`, signing in on the bare app domain with their own cookie. They guard Sidekiq::Web (a route constraint) and the church list/create console.
- **Alternatives:** A flag on User; HTTP basic auth for Sidekiq.
- **Reason:** Users are tenant-scoped, and platform operators aren't church members. Basic auth means shared credentials and no audit trail.

## 0.7 Permission keys live in code; roles store the keys they grant
- **Decision:** `Permission::ALL` is the fixed catalogue. `Role#permissions` is a string array validated against it. `grants_all` marks the church admin role so it gets permissions added in future releases. Policies call `user.can?(:key)`, which raises on unknown keys.
- **Alternatives:** Permissions table; hard-coded role checks in policies.
- **Reason:** Policies can reference permissions safely, typos fail loudly, and churches can still build custom roles later.
- **Guardrails:** Only church admins can grant or revoke church admin, and a church always keeps at least one church admin.

## 0.8 Audit events are written by model callbacks
- **Decision:** `AuditEvent.record!` is called from `after_create`/`after_destroy`/`after_update` on the audited models (UserRole grants/revokes, User deletion, Church settings). Actor and IP come from `Current`. Events are read-only once saved, and actor/auditable have no foreign keys, so the trail outlives what it describes.
- **Alternatives:** Audit calls in controllers; a gem such as audited or paper_trail.
- **Reason:** Callbacks inside the same transaction make audits impossible to skip and atomic with the change. We only audit a handful of important actions, which doesn't justify a gem.

## 0.9 Hosts: subdomain per church, bare domain for the platform
- **Decision:** `APP_DOMAIN` (default `localhost`) sets `tld_length`. `grace.localhost:3000` is a church, and `localhost:3000` is the platform console. Reserved subdomains (`www`, `admin`, `api`, …) can't be claimed.
- **Reason:** `*.localhost` needs no DNS setup in development.
- **Deferred:** Custom domains for church websites (Phase 10). If a marketing site later needs the bare domain, move the platform console to `admin.` (already reserved).

## 0.10 `json` pinned below 3.0
- **Decision:** `gem "json", "< 3"`.
- **Reason:** json 3.0 removed the positional options argument that `ActiveSupport::JSON.decode` in Rails 8.1.3 passes, which breaks jsonb columns. Remove the pin once Rails supports json 3.

## 1.1 Segments compile to one SQL query of EXISTS subqueries
- **Decision:** `Segment::Condition` turns each rule into a `WHERE` on people (usually `EXISTS (…)`), and `Segment::Query` joins them with `AND`/`OR`. Definitions are stored as validated jsonb.
- **Alternatives:** Joins with `DISTINCT`, filtering in Ruby, a query-builder gem (ransack).
- **Reason:** One query, no duplicate rows. The result is a normal relation, so paging, counting and `select(:household_id)` all work. Invalid conditions are rejected on save and skipped at query time, so a stale segment degrades instead of erroring.

## 1.2 Custom field values in `people.custom_fields` (jsonb) with typed definitions
- **Decision:** `CustomField` defines the key, type and choices. `CustomField#cast` normalizes each value into its JSON form (numbers, ISO dates, booleans, arrays) before storing. A GIN index backs segment lookups.
- **Alternatives:** EAV table of values; a column per field.
- **Reason:** Reads and writes need no joins, and a per-church schema needs no migrations. Casting at write time keeps comparisons (`->`, `@>`) exact. Keys can't change once created, and deleting a field removes its values.

## 1.3 Merges keep the absorbed person as a hidden record
- **Decision:** `Person::Merge` moves related rows to the survivor, fills blank details, and sets `merged_into_id`. `Person.unmerged` hides merged records everywhere: people scopes, segments, the duplicate finder and imports.
- **Alternatives:** Hard-delete the duplicate.
- **Reason:** Audit events and future references (donations in Phase 8) still resolve. Merges refuse when both people have logins, because a person has at most one User.

## 1.4 Location privacy is applied in SQL, before data leaves the server
- **Decision:** Users without `view_precise_locations` get households snapped to a 0.01° grid (`ST_SnapToGrid`, about 1 km) and counted per cell, with no names or ids. Exact coordinates never reach the page.
- **Alternatives:** Random jitter; hiding points in the browser.
- **Reason:** Jitter can be averaged away, and client-side hiding leaks the data. A grid is deterministic and easy to explain.

## 1.5 Geocoding: `Geocodable` concern and `GeocodeJob`, provider set by ENV
- **Decision:** Household, Group and Campus share `Geocodable`. It enqueues after commit when the address changes, but not when the same save set a location (seeds, and imports with coordinates). Geocoder raises on provider errors (`always_raise: :all`) so the job retries.
- **Reason:** Geocoding never happens inline in a request. Nominatim is the development default, but its usage policy forbids bulk use, so set `GEOCODER_LOOKUP` and `GEOCODER_API_KEY` for production.

## 1.6 Imports run in batches that can be resumed
- **Decision:** `PersonImport::Importer` commits every 100 rows together with `processed_count`. A retried job skips rows that were already committed. People are matched by email, households by street address and postal code, and a bad row is recorded without stopping the import.
- **Reason:** Jobs must be safe to retry. Staff see per-row errors (with spreadsheet row numbers) on a progress page that refreshes itself over Turbo Streams.

## 1.7 Ministry leadership is a record, not a role
- **Decision:** `MinistryLeadership` (user and ministry) lets a user manage that ministry's groups and teams. `manage_ministries` covers every ministry. Leaders can search people by name to add members without having `view_people`.
- **Reason:** Leadership is scoped to one ministry, and roles are church-wide. Only `manage_ministries` can appoint leaders, and appointments are audited.

## 1.8 Prayer visibility: pastoral staff, prayer team, shared
- **Decision:** `manage_prayer_requests` sees everything. `view_prayer_requests` sees prayer-team and shared requests, plus any assigned to them. Request text, answers and touchpoint bodies are encrypted. Prayer follow-ups become *sensitive* touchpoints, whose text is shown only to people with prayer access. Public and member submission come in Phase 2 (Forms) and Phase 3 (member area).

## 1.9 Tasks: board order stored per column
- **Decision:** `tasks.position` is scoped by status. `Task#move_to` renumbers the destination column in one `UPDATE … array_position`. Ideas live in a parked column, low-priority ideas are hidden by default, and the Done column only shows the last 30 days. Owners without `manage_tasks` can update, but not reassign, their own tasks.
- **Alternatives:** acts_as_list, or fractional positions.
- **Reason:** It's a few lines, runs as one statement, and needs no gem.

## 1.10 Small platform notes
- Active Storage tables (used for import files) aren't tenant-scoped, but their attachments belong to tenant-scoped records, and nothing reaches blobs except through those records.
- Leaflet's CSS is vendored in `vendor/assets/stylesheets` and linked only on the map page. OpenStreetMap tiles are used under their attribution requirement. Heavy production use should move to a commercial tile provider.
- Cuprite drives Chrome for JavaScript system specs. `*.localhost` subdomains resolve to 127.0.0.1 in Chrome, so church hosts work in specs.

## 2.1 One rule format, evaluated in Ruby and JavaScript, with a shared test fixture
- **Decision:** A field's show/hide rule is JSON (`{match, conditions: [{field, operator, value}]}`). `Form::Rule` evaluates it on the server, and `form_logic_controller.js` evaluates it in the browser. `spec/fixtures/files/form_rules.json` runs through both: RSpec for Ruby, and Cuprite calling the exported `evaluateRule` for JavaScript. The build fails if they disagree.
- **Alternatives:** Server-only logic (a round trip on every change); a JavaScript engine running inside Ruby.
- **Reason:** The stored rules are the single source of truth, the browser gets instant feedback, and the server is authoritative. Both sides use the same value shapes (`FormField#rule_value`) and the same number and date patterns, so `1_000` or `0x1A` can't mean different things in each language.

## 2.2 Visibility is decided top to bottom
- **Decision:** A field is visible when its rule holds for the *visible* answers above it. Answers to hidden fields are discarded on the server even if they were sent, and hidden required fields aren't required. The builder only offers earlier questions as conditions.
- **Reason:** No cycles, one pass, and the same behavior in both languages. Reordering can leave a rule pointing below itself; that condition then reads as empty rather than breaking.

## 2.3 Sensitive answers live in an encrypted column
- **Decision:** `form_submissions.answers` (jsonb) holds ordinary answers. Answers to fields marked sensitive go to `sensitive_answers`, JSON encrypted with Active Record encryption. Fields mapped to the prayer request body are always sensitive.
- **Alternatives:** Encrypt all answers (loses jsonb querying); keep everything in jsonb (plain-text prayer requests).
- **Reason:** Meets both requirements, answers in jsonb and prayer text never in plain text. Sensitive answers show only to `manage_forms` holders (general forms) or `manage_prayer_requests` holders (prayer forms), and are left out of other people's CSV exports.

## 2.4 Anonymous submissions only fill blanks
- **Decision (agreed with the product owner):** A signed-in submitter is always linked to their own person, and their mapped details are updated. An anonymous submission is matched by email; for a match it only fills blank details and never overwrites existing ones, because anyone can type anyone's email. With no match and a name given, a new guest is created. Mapped values that don't fit (for example a custom select choice the church doesn't have) are skipped.
- **Reason:** Regular attenders don't pile up as duplicates, and strangers can't change someone's record.

## 2.5 Submissions are processed in a job
- **Decision:** The public request only validates and saves. `FormSubmissionJob` then links the person, applies the mapping and the household address (geocoded as usual), creates the prayer request, and logs a touchpoint. `processed_at` makes it safe to repeat. The Phase 7 "form submitted" trigger will fire at the end of processing.

## 2.6 Public endpoint protection
- **Decision:**
  - Rails 8 `rate_limit`: 5 per minute and 30 per hour per IP.
  - A honeypot field.
  - A signed "form shown at" timestamp; submissions faster than 2 seconds are dropped.
  - Full server-side validation.
  - Uploads limited to one per field, 10 MB, images or PDF, with the type sniffed by Marcel rather than trusted from the browser.
- Suspected bots get the normal thank-you page, so there's nothing to probe.
- The test environment uses a memory cache store (cleared before each example) so rate limits can be tested.
- **Deferred:** Upload downloads use Active Storage's signed blob URLs. Moving them behind an authorizing proxy is worth doing when benevolence intake (Phase 8) adds documents.

## 2.7 Positionable concern
- **Decision:** `Positionable` (`positioned within: :status`, `#reposition(index)`) replaces the three copies of list-ordering code in Task, CustomField and FormField. It's genuinely shared behavior across three models, and each renumber is still a single `UPDATE`.

## 3.1 Occurrences are stored, with a local date
- **Decision:** `ServiceOccurrence`, `EventOccurrence` and `CourseSession` store `starts_at` and `ends_at` in UTC, plus `local_date` in the church's zone. Service occurrences are created for a date range only when a schedule needs them (`WorshipService#ensure_occurrences!`, which can safely run again), using the church's zone for each date, so 9am stays 9am across daylight saving changes. Calendars compute service times without writing anything.
- **Reason:** Assignments (and Phase 4 attendance counts) need a real row to point at. `local_date` makes "same day" conflicts, reminders and calendar grids simple queries.

## 3.2 `time` columns are wall-clock times
- **Decision:** `config.active_record.time_zone_aware_types = [ :datetime ]`.
- **Reason:** Rails converts `time` columns through `Time.zone` by default, so a 9:00 service start read during a Central-time request came back as 3:00. A service start or group meeting time is a time of day, not an instant. A regression spec reads it back under three zones.

## 3.3 One assignment model for services and events
- **Decision:** `PositionNeed` (polymorphic needable: WorshipService or Event) says how many people a position needs. `Assignment` (polymorphic schedulable: ServiceOccurrence or EventOccurrence) is a person in a position at one occurrence, unique on occurrence, position and person. Allowed types are whitelisted on both the model and the controller.
- **Reason:** The brief asks for events to reuse the same model, and conflicts and reminders then work the same everywhere.

## 3.4 Suggestions and auto-fill are plain Ruby, and never send anything
- **Decision:** `Scheduling::Candidates` filters by qualification, blockouts, being on this occurrence already, and monthly maximum. It flags people serving elsewhere that day, and ranks by recent load, recent declines, then longest since serving, with the reasons shown. `Scheduling::AutoFill` fills open slots with the best candidates (never double-booking a day) as pending assignments. Nothing is emailed until a leader clicks "send requests".
- **Reason:** Leaders stay in control, and the result is the same every time. The Phase 5 burnout check becomes one more ranking factor.
- **Performance:** The board works out conflicts for the whole grid in two queries, and loads each slot's suggestions lazily in a Turbo Frame when opened.

## 3.5 Capacity and waitlists share one concern; booking locks the row
- **Decision:** `Waitlistable` (event occurrences by party size, course offerings by person). `Registration::Booking` and `Enrollment::Booking` lock the occurrence or offering, then seat or waitlist. Cancelling or withdrawing promotes the oldest waitlisted booking that fits, and emails them. A spec with two real concurrent connections proves the last seat can't be double-booked.

## 3.6 Links in emails are secret tokens that open a page
- **Decision:** Assignment responses (`/respond/:token`) and registration management (`/registrations/:token`) use `has_secure_token`. The GET shows buttons; only PATCH or DELETE changes anything.
- **Reason:** Mail scanners and link previewers follow GET links, so an accept/decline link must never answer on its own.

## 3.7 Member accounts: invitation or self-claim, no open sign-up
- **Decision (agreed with the product owner):** Staff with `manage_users` can email "set up your account". Anyone can ask for the same link at `/account_setup/new`. It's sent only to an unmerged person with that email and no login, and the reply is the same either way. The link is `Person#generate_token_for(:account_setup)`: valid for 7 days, and it stops working once an account exists or the email changes. Completing it creates a User with the Member role and signs them in. Unknown people use the Connect card.

## 3.8 Member area is a namespace over the signed-in person
- **Decision:** `Member::` controllers under `/me`, with a mobile-first layout and bottom navigation. Every record is reached through `Current.user.person` (their assignments, registrations, enrollments, household), so members can only touch their own. After sign-in, users with any permission or ministry leadership land on the admin dashboard; everyone else lands on `/me`.

## 3.9 Mail for now: Action Mailer + SMTP, sent in the church's name
- **Decision:** Mail is sent from `no-reply@MAIL_DOMAIN` with the church's name as the sender, and `Reply-To` set to the church's contact email. Links use the church's own subdomain (`ApplicationMailer#url_options`). Development uses letter_opener_web, and every template has a preview (checked by a spec).
- **Deferred:** Phase 6 routes mail through each church's `Email::DeliveryProvider`, with suppression and unsubscribe handling.

## 3.10 Reminders: an hourly sweep that runs at each church's 8am
- **Decision:** sidekiq-cron runs `ReminderSweepJob` hourly. For each church where it's 8am local time, `Scheduling::Reminders` emails volunteers `reminder_days_before` days ahead and registrants the day before. `reminded_at` and `reminders_sent_at` make each reminder go out once.

## 3.11 Public endpoint protection is a shared concern
- **Decision:** `PublicSubmissionProtection` (rate limits, honeypot, signed fill-time token) now protects both public forms and public event registration.

## 4.1 Headcounts per service occurrence, with a church-defined breakdown
- **Decision:** `AttendanceCount` stores one `total` per service occurrence, plus an optional `breakdown` (jsonb) by the church's `attendance_categories` (default Adults, Kids, Online) and a `first_time_guests` count. With a breakdown, the total is its sum. A category named "Online" counts as online; every other category is in person.
- **Reason:** Most churches count heads rather than people; categories vary by church. Individual check-ins (`Attendance`) are separate and optional, and mark a person's first-ever check-in.

## 4.2 A transparent forecast, in plain Ruby, that explains itself
- **Decision (agreed with the product owner):** forecast the total headcount, and show an expected in-person/online split from recent shares.
- **How `Attendance::Forecast` works** (a pure function over history before the date):
  - Baseline: the average of the last 6 ordinary weeks.
  - Trend: a least-squares line over 12 months, projecting forward.
  - Special-day effect: learned from the church's own past days of that kind; a church-entered % wins; otherwise a documented default.
  - Last year: the same week (or the same holiday) last year × year-over-year growth, blended 50/50.
  - Range: the 80th percentile of past errors, at least ±5%.
  - Every step is a stored factor, and the factors sum to the expected number, so staff can see exactly why a number moved.
- **Alternatives:** An opaque statistical model or ML service.
- **Reason:** Staff can check and trust it, and it can be tested exactly.

## 4.3 Year-over-year growth compares whole years, not a regression slope
- **Decision:** The growth applied to last year's number is the last 12 months of ordinary weeks against the 12 months before. The regression line is used only for the short-term trend.
- **Reason:** In testing, a slope over the trailing year read the latest summer dip as a 4% annual decline while the data was actually growing 7%, so September was consistently under-forecast. Comparing two whole years cancels out seasons. On the demo history, the mean error fell from 6.5% to 4.3%, and the share of Sundays landing inside the range rose from 58% to about 75% (the target is 80%).

## 4.4 Forecasts are stored, then frozen
- **Decision:** `AttendanceForecast` is one row per service occurrence. It's refreshed when counts are entered and by the 2am sweep, and frozen once the service starts. Accuracy compares frozen forecasts with the counts that came in. Ranges are sized from stored errors once 8 exist, and from a back-test of the model on recent weeks before that.
- **Reason:** "How accurate were we?" must compare what we actually predicted at the time, not a forecast recomputed afterwards.

## 4.5 Special days: Easter in code, holidays from the gem, the church's own by name
- **Decision:**
  - `Attendance::Easter` uses the anonymous Gregorian algorithm, checked against known dates including the earliest (Mar 22) and latest (Apr 25).
  - The `holidays` gem supplies Mother's and Father's Day, Memorial Day and Labor Day weekends (the Sunday before the Monday), Thanksgiving weekend, and July 4th (within 3 days).
  - Christmas and New Year's Sundays are date windows.
  - Church-marked `SpecialSunday`s are keyed by name, so "Back to school" in different years teaches one effect.

## 4.6 Charts: Chartkick on Chart.js, one validated palette, always with a table
- **Decision:** `ChartsHelper` fixes the styling for every chart:
  - Series colors in a fixed order (blue, orange, aqua), validated for colour-blind separation. The aqua is low-contrast, so every chart has a "Show the numbers" table.
  - 2px lines, points only on hover, solid rounded bars, a quiet grid, no dual axes.
  - Line charts don't start at zero; bar charts do.
- **Queries:** Groupdate buckets weeks and months. The monthly year-over-year chart reads both years' weekly totals in one query.

## 4.7 A warning for precompiled assets in development
- **Decision:** When `public/assets/.manifest.json` exists in development, Rails prints a warning at boot.
- **Reason:** Propshaft then serves only precompiled files, so new CSS and JavaScript silently stop loading. That caused broken pages four times during Phases 2–4. The fix is `bin/rails assets:clobber`; use `bin/dev`.

## UI.1 Collapsible sidebar sections
- **Decision:** Each sidebar heading is a native `<details>`/`<summary>`, so it works with the keyboard and without JavaScript. The section holding the current page is open when the page loads. `nav_sections_controller.js` remembers which other sections each person has opened, in that browser's localStorage; if storage isn't available, it simply doesn't remember. The section list lives in `NavigationHelper` and is shared by the phone and desktop menus. Exactly one link is highlighted: the longest one the current path matches.

## 5.1 Pathway stages are segment rules; placement is the highest stage met
- **Decision:** `PathwayStage#definition` uses the segment format, is edited with the same builder, and gets a live preview of how many people each stage would hold.
- **How placement works:** `Pathway::Placement` runs one query per stage, from the top down, and places each person at the highest stage whose rules they meet. The first stage has no rules.
- **Defaults:** Grow = in any active group *or* taking or finished a course. Serve = on a team *and* served in the last 60 days.
- **Restriction:** Stage rules can't use pathway or stuck conditions, which would be circular.
- **Other uses:** The new conditions (course, attendance, serving, pathway stage, stuck) are also available to segments and the map.

## 5.2 People move back when the facts lapse
- **Decision (agreed with the product owner):** The stage reflects what's true now. Moving back is recorded as a `back` transition, and the dashboard counts forward and back movement separately.
- **Reason:** "Stage is derived from facts," and stuck detection only means something if stages are current.

## 5.3 Placement: kept current by events and a nightly sweep, with every change recorded
- **Decision:**
  - `AffectsPathway` is a concern shared by six models (group and team memberships, enrollments, assignments, check-ins, tags), plus membership-status changes on Person. It queues `PathwayPlacementJob` for that person.
  - `PathwaySweepJob` re-places everyone at 3am in each church's time zone, so time-based rules and stuck status stay current. Changing stages or rules re-places everyone right away.
  - Only changes are written. Each creates a `PathwayTransition` (placed, forward or back) and sends a `pathway.stage_changed` notification, which is the hook for Phase 7 workflows.
- **First placement:** Connect is dated from when the person was added; other stages from launch. Earlier movement isn't reconstructed.
- **Placement reads stages fresh from the database:** Rails' `has_many_inversing` adds unsaved stages to `pathway.stages`, so an unsaved record once showed up in the preview as a rule-less top stage holding everyone.

## 5.4 Stuck and funnel numbers
- **Stuck:** Longer in a stage than its `stuck_after_days` (Connect 90, Grow 180 by default), computed in SQL. The last stage is never stuck.
- **Conversion:** Of the people who entered a stage in the last 12 months, the share who later reached the next stage.
- **Median time:** Days between entering a stage and entering the next.
- **Dashboard:** Shows the 25 longest-stuck people, with a link that builds a segment of everyone stuck.

## 5.5 Volunteer load is assessed on demand, in batch, and never blocks scheduling
- **Decision:** `Volunteering::LoadAssessment` loads assignment history for a set of people once, then rates anyone as of any date, optionally with one more assignment.
- **Measures:**
  - Weeks served in a row, counting back from this week, or from last week if they haven't served yet this week.
  - Assignments a week over the last 8 weeks.
  - Teams, and the share of recent requests declined.
  - Weeks since last served.
- **Ratings:** at risk, elevated, underused (on a team for 8+ weeks without being scheduled) or healthy, using thresholds from `Church#volunteer_load_thresholds`.
- **Scheduling:** Suggestions rank at-risk people last and elevated people lower, with the reason shown. The board shows a badge and warns when a new assignment pushes someone to at risk. It never blocks; leaders decide.
- **Why not stored:** Nothing is stored yet. Phase 9 insights read the same assessment.

## 5.6 Small fixes found along the way
- The sidebar re-ran every permission check several times per page; the section definition is now built once per page (50 → 15 queries on the team page).
- The builder's JavaScript builds URLs with the `URL` API, so URLs that already carry a query string (like the stage builder's) still work.

# Phase 6: Email

## 6.1 MJML through MRML, Liquid in strict mode
- **MJML compiler:** `mjml-rails` in MRML mode (a Rust port through the `mrml` gem), so no Node process runs in production. Chosen by the user.
- **Liquid:** Section Liquid runs in its own `Liquid::Environment` with these safeguards:
  - Strict parsing, strict variables and strict filters, so a typo raises an error instead of rendering blank.
  - Resource limits.
  - Only drops for the data. No models are exposed.
- **Markdown:** The `markdown` filter (Commonmarker) escapes raw HTML.

## 6.2 Two-pass rendering
- **Pass one:** `EmailTemplate::Renderer#compile` runs once per campaign.
  - Section Liquid runs with data that's the same for everyone: settings, theme, church and upcoming events.
  - Per-recipient values stay as `{{ person.* }}` and `{{ links.* }}` placeholders.
  - The MJML becomes HTML, and links are rewritten for tracking.
  - The result is saved as `campaigns.html_snapshot`.
- **Pass two:** Each delivery only runs Liquid over that HTML. A thousand recipients means one MJML compile, not a thousand.
- **Snapshot:** Editing a template after sending never changes what went out.

## 6.3 Sending is once-only per recipient
- **Dispatch:** `Campaign::Dispatch` locks the campaign and inserts deliveries with `insert_all`, unique on campaign and person, then queues batches of 100. Running it again adds no one.
- **Sending:** `Delivery::Sending` locks each delivery and only proceeds from `queued`, moving it to `sending` first. It then:
  - Re-checks suppressions just before sending.
  - Personalises the subject and HTML.
  - Adds `List-Unsubscribe` and `List-Unsubscribe-Post` (one-click).
  - Logs an email touchpoint.
- **Remaining gap:** If the provider accepts a message and the process dies before we save that, a retry can send it again. Providers offer no idempotency key for this. Deliveries stuck in `sending` are left for a person to look at, not retried automatically.
- **Completion:** The campaign becomes `sent` once no deliveries are queued or sending.
- **Scheduling:** `CampaignSchedulerJob` runs every five minutes and starts any scheduled campaign that's due.

## 6.4 Providers behind one interface
- **Interface:** `Email::DeliveryProvider` has three methods: `deliver(message)`, `verify_webhook!(request)` and `events_from(webhook_event)`.
- **Adapters:** Postmark (its gem, with broadcast and transactional message streams), SES (SESv2 raw MIME, with events through SNS verified by the SDK's `MessageVerifier`) and Platform.
- **Platform:** The app's own delivery (letter_opener in development, test deliveries in tests, SMTP in production).
- **All church mail:** Action Mailer uses the `:church` delivery method (`Email::ChurchDeliveryMethod`) in every environment, so receipts and reminders also go through the church's provider. It skips addresses that hard-bounced or complained.
- **No provider connected:** Mail uses the platform sender. Campaigns only fall back to the platform outside production (`config.x.platform_campaigns`), so a church's bulk mail can't hurt the platform's shared reputation.
- **Vendor details:** Webhook payload parsing, Postmark basic-auth webhooks and the Mailchimp batch upsert are written from memory of the vendor APIs. They're marked `TODO(verify vendor docs)`, and their specs stay pending until someone checks them against the documentation.

## 6.5 Webhooks, unsubscribes and tracking
- **Webhooks:** `POST /webhooks/:token`.
  - The token finds the integration.
  - The provider's signature or credentials prove the request is real.
  - The raw body is stored before anything else and processed in `EmailWebhookJob`.
  - Replaying is safe: status updates are idempotent and suppressions are unique.
- **Unsubscribe:** Opening `GET /u/:token` only asks for confirmation, so link scanners can't unsubscribe anyone. `POST` unsubscribes, including the RFC 8058 one-click POST, which skips CSRF.
- **Preferences:** The link uses `Person#generate_token_for(:email_preferences)`. It stops working if the person's email changes.
- **Tracking:** Clicks redirect only to URLs signed when the campaign was compiled, so the endpoint can't be used as an open redirect. The report labels opens as approximate. A campaign can turn tracking off.
- **Postal address:** Campaigns can't send without the church's postal address, which CAN-SPAM requires. It appears in every footer.

## 6.6 Credentials are write-only in the UI
- **Permissions:** Only people with `manage_integrations` (church admins by default) can connect providers. Staff with `manage_email` can send campaigns but never see keys.
- **Forms:** Saved values are never shown in forms. Leaving a field blank keeps the stored value.
- **Webhook log:** Stored headers are limited to `X-*` and the content type, so basic-auth secrets are never stored.

## 6.7 Email images are stored by reference and resized on the server
- **Storage:** Uploads are saved as their Active Storage path, not a full URL. The host is added at render time: the request's own URL for the editor preview, and the church's public address for sent email.
  - **Why:** The first version saved absolute URLs without the development port, so uploads didn't show.
  - **Existing uploads:** Older absolute URLs are still recognised.
- **Resizing:** Width, height and fit (best fit, center, stretch, crop) are applied by vips variants (`Email::ImageSource`), because Gmail and Outlook ignore CSS `object-fit`.
  - Images are rendered at 2× for sharp screens.
  - Best fit and center pad with the template's content background.
  - Formats email clients can't show, like HEIC, become JPEG.
  - Pasted image URLs are only given width and height.
- **Upgrades:** Built-in sections carry a schema version (`SectionDefinition::Defaults::VERSION`). Existing churches pick up changes to built-in sections the next time they're used.

# Phase 7: Workflows

## 7.1 Drafts and versions
- **Decision:** Staff edit `workflows.draft_definition`. Publishing copies it into a new numbered `WorkflowVersion`. Each run points at its version and finishes on it, even after later publishes.
- **Step ids:** Steps have ids that never change, so runs, executions and edits can refer to a step across versions.
- **Definition shape:** JSON: `{ trigger, entry, steps }`. An if/else step keeps its branches inline as `yes` and `no` lists. `Workflow::Definition` handles navigation: entering a branch, and continuing after it ends.
- **Alternative considered:** Editing live definitions in place. Rejected because in-flight runs would jump between versions.

## 7.2 Once-only step execution
- **Decision:** `WorkflowStepJob` runs `Workflow::Execution` in three parts:
  1. **Claim, with the run locked:** the job must be for the run's current step. It then creates or reclaims the step's `WorkflowStepExecution`, which is unique on run and step.
  2. **Perform, with no lock or transaction.**
  3. **Apply the outcome, with the run locked.**
- **Why step 2 has no transaction:** Sends happen in step 2, so a later rollback can never erase the record of an email that already went out.
- **Retries:** A retried job finds a finished execution and only advances the run.
- **Steps are safe to repeat:**
  - Deliveries, tasks and message drafts are unique per execution.
  - Tags and campaign additions use find-or-create.
  - A second job for the same step backs off while the claim is less than 10 minutes old.
- **Failures:** A failure marks the execution and the run as failed, with the error. Staff can retry from the run page.
- **Waits:** Waits are scheduled jobs (`set(wait_until:)`). A job that wakes early does nothing.

## 7.3 Guardrails
- **Re-entry:** A partial unique index on `workflow_runs (workflow_id, person_id)` covers runs that are active or waiting. It stops someone entering the same workflow twice at once, unless the workflow allows re-entry; the run records that choice as `allow_concurrent`.
- **Pause and kill switch:** Pausing stops runs at their next step, and resuming picks them up (`WorkflowResumeJob`). "Stop all runs" cancels every run in progress.
- **Daily send limit:** The church-wide cap (`churches.workflow_daily_send_limit`) moves sends over the limit to 8am the next day. Nothing is dropped.
  - Sends staff approve by hand don't count toward the limit.
- **Morning sweep:** The "missed N weeks" and date triggers are checked by an hourly cron job that acts at 6am in each church's time zone.
  - At most one run per person per workflow per day, and "missed" starts one run per absence.

## 7.4 Workflow emails reuse campaign delivery
- **Decision:** Deliveries can come from a workflow step instead of a campaign. `deliveries.workflow_step_execution_id` is unique, and the delivery stores its own subject, HTML and topic.
- **What they share with campaigns:** `Delivery::Sending` handles both, so workflow emails get the same suppression checks, topic preferences, unsubscribe headers, tracking and provider. They're logged as `workflow_message` touchpoints.
- **"Add to a campaign":** adds the person as an extra recipient of a draft or scheduled campaign. If the campaign has already gone out, the step is skipped and the reason is recorded.
- **Update pathway:** "Update pathway stage" re-checks the stage; it can't force one, because stages come from facts. An if/else on the pathway stage acts on the result.
- **Notify staff:** email only for now.

## 7.5 AI runs on a self-hosted Ollama server
- **Decision (user's call):** `Assistant::Client` → `Assistant::Providers::Ollama` → `POST $OLLAMA_URL/api/chat` with the model from `ENV["AI_MODEL"]`. `OLLAMA_API_KEY` is optional, for a server behind an authenticating proxy.
- **Why:** Church data never goes to a third-party AI service.
- **Every call:** checks the church's AI switch (off by default) and its monthly token cap, and is logged as an `AiRequest`.
- **Vendor check:** The request and response fields are marked `TODO(verify vendor docs)`, and one spec stays pending until they're checked against the deployed Ollama version.
- **What the AI sees for a draft:** the person's first name, membership status, pathway stage, how many groups and teams they're in, and the kinds and dates of their five most recent non-sensitive touchpoints.
  - It never sees prayer or benevolence content, notes, emails or phone numbers.
- **Drafts:** always become a `MessageDraft` in the approval queue.
  - A church admin can turn on auto-send for a step, and each change is audited (`workflow.auto_send_enabled` / `disabled`).
  - When AI is off, over the cap or unreachable, the draft still lands in the queue marked "write this yourself". The run is never blocked.
- **Liquid in drafts:** Drafted text is kept from being read as Liquid, with a zero-width space after `{`, so a stray `{{` can't break sending.

## 7.6 Builder
- **Layout:** A vertical step list. Each list, including each branch, can be reordered by dragging (Sortable). Step settings open inline in a Turbo Frame, and saving reloads the page so the publish checklist stays current.
- **Rules:** Entry conditions and if/else rules reuse the segment condition builder.
- **Starters:** The starter workflows (New member welcome, First-time guest follow-up, Missed 3 weeks check-in) are installed as drafts, so staff choose who gets the tasks and alerts before publishing.

# Phase 8: Giving and benevolence

## 8.1 Giving is read-only, behind one provider interface
- **Interface:** `Giving::Provider` defines `funds`, `each_donation(since:, until:)` (paged), `verify_webhook!` and `donations_from(webhook_event)`. Each returns plain `FundRecord` and `DonationRecord` values.
- **Import and matching:** `Giving::Import` upserts by external id, so re-importing changes nothing and a refund updates the original gift. `Giving::Matching` then matches new gifts.
- **Reconciliation:** `Giving::Reconciliation` re-fetches from 7 days before the last run. It runs nightly at 2am church time, or from "Sync now".
- **Webhooks:** They use the shared `/webhooks/:token` endpoint. `IntegrationWebhookJob` (formerly `EmailWebhookJob`) picks the processor by integration category.
- **Read-only:** Amounts are integer cents with a currency (`Money`). Only who a gift is matched to can change here.

## 8.2 The Tithe.ly adapter is intentionally unfinished
- **Status:** No Tithe.ly API documentation has been provided. `Giving::Providers::Tithely` raises instead of guessing: sync fails with a clear message, and webhooks are rejected, so nothing unverified is stored as giving.
- **Tests:** Pending specs describe what's needed (funds, paged transactions with refunds, webhook signatures).
- **What already works:** Everything above the adapter is built and tested against the interface: import, matching, reconciliation, the review queue and the reports.

## 8.3 Matching order
1. A known `DonorLink` for the platform donor id.
2. Exactly one unmerged person with the donor's email. Shared emails don't auto-match.
3. Otherwise the gift waits in the review queue.

- **Manual matches:** A manual match creates the DonorLink and also matches that donor's other waiting gifts.
- **Queue layout:** The queue shows one card per donor, with likely matches by email and name similarity (pg_trgm). Staff can add the giver as a new person or leave them unmatched.

## 8.4 Benevolence permissions and auditing
- **Permissions:** Three new permissions, `view_benevolence`, `manage_benevolence` and `approve_benevolence`, and a new "Benevolence team" system role (view and manage).
  - Staff get none of these by default; church admins have all three.
  - The benevolence team can create and edit benevolence funds only.
- **Auditing:** Opening a case writes `benevolence_case.viewed`. Opening, editing, each approval or denial, the final decision and each payment are audited too.
  - The list and the report show no private text, so they aren't logged as case views.
- **Encryption:** Case text, notes, approval notes and payment references are encrypted, as are donor names and emails.
- **Forms:** A new form purpose, `benevolence_request`, with a starter "Request financial help" form. Its mapped answers are sensitive, so they're encrypted.
  - The case is opened by `FormSubmission::Processing`.
  - It writes no timeline touchpoint and fires no workflow trigger, and benevolence forms can't be chosen as triggers.
  - Opening the submission redirects to the audited case.

## 8.5 Approval rule (the user's choice)
- **At or below the threshold:** one person with `approve_benevolence` decides.
- **Above the threshold:** the church's setting (1 or 2 approvals) from people who didn't open the case and aren't handling it.
- **Outcome:** Any deny denies the case. The approved amount is the lowest amount approved.
- **Payments:** Payments can't exceed what's approved and remains unpaid.
- **The 12-month limit:** a warning, not a block. It's per household by default, per person optionally, and 0 means no limit.

## 8.6 No max-width layouts
- **Decision (the user's call):** Tailwind `max-w-*` classes were removed across the app and aren't used in new views. Pages and forms fill the available width.

# Phase 9: Insights and AI

## 9.1 Insights are plain Ruby checks with one live record per situation
- **Checks:** Each check (`Insights::Detectors::*`) returns findings. `Insights::Sweep` runs them at 4am church time.
  - It upserts by fingerprint (kind + subject; Sunday spots also include the date), with a partial unique index on live insights.
  - It resolves insights whose condition cleared, with the resolution "cleared".
  - It reopens snoozed insights when the snooze ends.
  - It stays quiet about dismissed ones while the condition continues.
- **Tasks:** Finishing a task resolves insights about it and insights turned into it.
- **Aggregated checks:** Checks that could flood the list (stuck on the pathway, no recent contact, tasks without an owner, underused volunteers) produce one insight each, with a count.
- **Private queues:** Queue checks (donors to match, messages to approve, benevolence decisions, failed workflow runs) report counts only, and only to the permission that handles them.
- **Visibility:** An insight shows to anyone with its audience permission, and to the people it belongs to directly (task owner, ministry or group leaders).

## 9.2 The brief: rules first, AI on top, AI kept in bounds
- **Rules:** `Insights::Ranking` scores by severity, then whether the insight belongs to the user directly, then age.
- **AI:** `Insights::Brief` sends the top 15 to the AI: kind, severity, age, title and numbers, with no notes, private text or contact details. It asks for JSON with an order, a reason for each, and a brief.
  - Ids the AI wasn't given are dropped, and anything it leaves out is appended in rule order.
  - An unusable answer, AI being off or over its limit, or the server not answering all fall back to rules.
- **Delivery (the user's call):** The brief is on the dashboard. The 6am email is opt-in per user.

## 9.3 The report assistant can only know what the tools return
- **The loop:** `Reports::Assistant` runs a tool-calling loop (at most 5 rounds) over the self-hosted Ollama server.
  - It only sees the tools available to the user, and each call is checked for permission again when it runs.
  - Tools run inside a savepoint, so one failing query can't break the rest.
  - The AI never writes SQL.
- **Number check:** `Reports::NumberCheck` flags any figure in the answer that doesn't appear in a tool result, a tool argument or the question. Years and list numbers are allowed, and rounding and percentages are matched loosely.
  - Flagged figures are shown as "Not from the data".
- **"Based on" panel:** Every answer shows the tools used, their inputs, and the full figures and tables.
- **Vendor check:** Ollama tool calling (the `tools` field, `message.tool_calls`, and `role: "tool"` results) is marked `TODO(verify vendor docs)`, with a pending spec. It needs a model that supports tools.
- **Background answers:** Answers run in `ReportAnswerJob`, and the page polls a Turbo Frame (the `poll` Stimulus controller). This avoids depending on ActionCable.

## 9.4 Reporting works without AI
- **Metrics page:** runs any tool from a form.
- **Saved reports:** store the tool calls as they were asked, so relative defaults like "this year" stay relative. Re-running executes the calls again, deterministically.
  - Pinned reports refresh nightly and show on the dashboard.
- **Private totals:** Prayer and benevolence totals are a separate tool. It's offered only when a church admin turns on "include prayer and benevolence totals", and only to people with those permissions. Counts and dollar totals only, never text.

# Phase 10: Website builder

## 10.1 Sites live on their own domain (the user's call: option A)
- **Addresses:** `grace.<SITES_DOMAIN>` (`grace.sites.localhost:3000` in development), plus verified custom domains. The admin app stays on `grace.<APP_DOMAIN>`.
- **Why:** Pages run church-written Liquid and HTML, and a separate registrable domain means that code can never read staff sessions or cookies.
- **Routing:** The `SiteHost` routes come first, because a sites-domain host also looks like a church subdomain.
  - A route-level `constraints:` replaces the block's, so the catch-all route repeats the `SiteHost` check.
  - Forms and event pages are also served on site hosts, so embedded forms submit to the site's own domain.
- **Tenancy:** `ChurchTenancy` resolves the church from a site host too, and sets `Current.site`.
- **No sessions:** `Sites::BaseController` has no sessions, sign-in or browser check.

## 10.2 Custom domains: CNAME verification and on-demand TLS
- **Verification:** A domain is verified by a live DNS check (`Site::DnsCheck`): a CNAME to `SITES_CNAME_TARGET`, or, for a bare domain, A records that are all in `SITES_APEX_IPS`.
  - It's checked hourly for 7 days, or on demand.
  - A hostname can belong to only one site across the platform.
- **HTTPS:** Certificates come from a TLS proxy with on-demand issuance (Caddy's `on_demand_tls`). The proxy asks `GET /internal/tls/allowed` (`TlsChecksController`), which only says yes for our hosts and verified domains.
  - kamal-proxy can't issue certificates for hostnames added at runtime. See `docs/deploy-sites.md`.
- **Allowed hosts:** Production `config.hosts` allows verified domains through a lambda (`SiteDomain.verified_host?`, cached for a minute). Host regexes are written without anchors, because Rails adds them and an optional port.

## 10.3 Pages are the email section model, with a draft and a published copy
- **Shared code:** `HasSections` (extracted from `EmailTemplate`) edits the ordered JSON section list for both email templates and pages.
- **Drafts:** Pages keep `draft_sections` and `published_sections`. Publishing copies the draft, writes a `PageRevision` (the last 20 kept), and clears the site's cache.
- **Offline switch:** The whole site also has a live/offline switch.
- **Built-in sections:** 16 web sections are installed per church from `app/sections/web`, and versioned like the email ones. A section a church edited in advanced mode is marked `customized`, so updates skip it. "Reset" restores the original.

## 10.4 Rendering and what Liquid can see
- **Order:** `Site::Renderer` renders each section, then the theme layout around them (`{{ head }}`, `{{ content_for_layout }}`). It uses the same strict, resource-limited Liquid sandbox as email.
- **Drops only:**
  - site, church (public info), page and nav;
  - published public events;
  - active groups (town only, never a street address);
  - service times and campuses;
  - published public forms (not event-registration or benevolence forms).
- **Loaded only when used:** Data is passed as lambdas, so it only loads if a section uses it.
- **Broken sections:** A broken section is left out for visitors (and logged). In the draft preview it's shown as a visible error.
- **Video:** Video embeds accept YouTube (the privacy-enhanced domain) and Vimeo only.
- **Embedded forms:** They render the same fields, honeypot and fill-time token as `/f/:slug`.

## 10.5 Styling: Tailwind plus theme CSS variables
- **Tailwind:** The built-in section and layout files are scanned by Tailwind (`@source`), so they can use utilities, including `bg-(--site-brand)` style variables.
- **Themes:** Each theme adds a small stylesheet (`app/assets/stylesheets/themes/<key>.css`). The site's settings become CSS variables in `<head>`.
- **Custom sections:** Sections written in advanced mode can use the theme classes (`site-section`, `site-card`, `site-button`, `site-heading`) and any Tailwind class the built-ins already use.
- **Width:** No max-width anywhere. Sections are full width with generous padding (per the user's rule in 8.6).

## 10.6 Caching
- **Cache:** Published pages are cached in Redis (the cache store), keyed on the site's `content_version`, theme and page.
- **Clearing:** Publishing bumps the version, and so does any change to events, occurrences, groups, forms, services or campuses (`ExpiresSiteCache`), so live sections stay current. A 15-minute expiry is the backstop, for things like events ending.
- **Naming:** The column is `content_version`, because `cache_version` is an Active Record method.

## 10.7 Advanced mode
- **Permission:** Advanced mode needs `develop_website` (church admins by default). Simple mode needs `manage_website` (staff by default).
- **Editor:** CodeMirror 6 is vendored through the importmap (`vendor/javascript`). Liquid is checked on save. Schemas are edited as JSON, and invalid JSON is reported.
- **Layout:** A custom layout must include `{{ head }}` and `{{ content_for_layout }}`. "Use the theme's layout" discards it.

## 10.8 Small fixes found along the way
- **`config.x.dev_port`:** it's an empty options object (which is truthy) outside development, so URLs got `:{}` in tests. It's now checked with `.presence`.
- **robots.txt:** Rails' static `public/robots.txt` shadowed per-site robots.txt, so it was removed. Sites answer with their sitemap; the admin app and platform console answer "Disallow: /".

# Phase 11: Social media

## 11.1 One platform Meta app, one fixed OAuth callback
- **One app:** The platform owns a single Meta app (`META_APP_ID`, `META_APP_SECRET`), and churches authorize it for their own Pages.
- **Why one callback:** Meta needs redirect URIs registered in advance, and churches live on their own subdomains. So the flow returns to `https://<APP_DOMAIN>/oauth/meta/callback`.
  - A signed, 15-minute `state` names the church and user.
  - The callback swaps the code for tokens, saves the Pages and linked Instagram accounts, then sends the user back to their church.
- **Meta's required callbacks:** Deauthorize and data deletion (`MetaCallbacksController`) verify Meta's signed request with the app secret. They disable the integration and clear its tokens.
- **Tokens:** Page tokens (Instagram posts use the linked Page's token) and the long-lived user token are stored encrypted.

## 11.2 The Meta adapter is written from my understanding, not from verified docs (the user's call)
- **Status:** `Social::Providers::Meta` covers the OAuth flow, Page feed and photo posts, Instagram's container-then-publish flow (including carousels), permalinks, `/debug_token`, and error mapping.
  - Error mapping: code 190 means reconnect, and `is_transient` or rate-limit codes mean retry.
  - The Graph API version is pinned (`META_GRAPH_VERSION`, default v21.0).
- **Verification:** Every call is marked `TODO(verify vendor docs)`. The specs stub the calls as written, and pending examples list what to verify.
- **Meta's App Review:** the steps, permissions and callbacks are in `docs/deploy-social.md`.

## 11.3 Each post goes out at most once
- **Claim, then call:** `Social::Publishing` locks a target and moves it pending → publishing before calling Meta, then records the result.
- **Transient errors:** they retry with backoff (5 minutes, 30 minutes, 2 hours) and fail after 3 attempts. Other errors fail right away.
- **Unknown outcomes:** a target left "publishing" for 15 minutes (a crashed job) becomes `unknown` and is never retried automatically. Staff check the network, then choose "It posted" or "Try again".
- **Post status:** the post's status is worked out from its targets.
- **The sweeper:** `SocialPublishSweepJob` runs every minute and queues due targets. A per-account caption overrides the post's text for that network.

## 11.4 Network rules and photos
- **Rules before scheduling:** `Social::Validation` checks each network's rules before a post can be scheduled. Instagram needs a photo, allows 2,200 characters and 10 photos, and has no clickable links (so the link is added as "Link in bio"). The composer shows each problem.
- **Photos:** JPEG or PNG only. They're sent to Meta as public URLs on the church's website address, because Meta downloads them.

## 11.5 Event promos are drafts, never auto-posted
- **Promo drafts:** When a public event is published (on create or update), `SocialEventPromoJob` drafts a post: the title, the next date, time and place, a short description, and the link to the event on the church website.
  - It's one per event (a partial unique index).
  - Its Facebook Pages are ticked by default; Instagram isn't, because it needs a photo.
- **Setting:** a church setting (`social_event_promos`) turns this off. The calendar still offers "Draft a promo" for events without a post.
- **Polish with AI:** available when AI is on. It rewrites the draft through Ollama, is logged, and never posts anything.

## 7.7 The Ollama format is verified (development setup)
- **Verification:** The request and response format (`/api/chat`) and tool calling (`tools`, `message.tool_calls`, and `role: "tool"` results) were checked against Ollama 0.30.3 with gpt-oss:20b.
  - The real responses are kept as fixtures in `spec/fixtures/files/ollama`, and the Ollama `TODO(verify)` markers are resolved.
- **Reasoning models:** Models like gpt-oss return `message.thinking`, and those tokens count against `num_predict`. `AI_THINK` sets Ollama's `think` option (`low` in development).
  - When reasoning uses up every token, the error says so, rather than just "empty reply".
- **Development defaults:** `config/environments/development.rb` sets `OLLAMA_URL`, `AI_MODEL` (gpt-oss:20b) and `AI_THINK` if they aren't already in the environment. Production still needs them set explicitly.
- **Prompt fixes found by real use:**
  - The daily brief asks for `brief` first in its JSON; the model had left it out.
  - Workflow drafts are told that membership status and pathway stage are background only, after a draft told a guest about "our Grow pathway community".
