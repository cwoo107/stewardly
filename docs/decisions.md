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
