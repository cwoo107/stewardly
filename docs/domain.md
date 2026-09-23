# Domain glossary

Use these names consistently. **Bold** entries exist in the code today; the rest are reserved for later phases.

## Tenancy and access
- **Church**: the tenant. Has a subdomain and a time zone; all date math ("this Sunday", reports, schedules) happens in the church's zone. Timestamps are stored in UTC.
- **PlatformAdmin**: operates the SaaS. Not tied to any church, signs in on the bare app domain.
- **Campus**: a physical site with a location; every church has one default campus.
- **Person**: anyone the church knows about: members, guests, children, contacts. Most never log in. Has a `membership_status` (guest, regular attender, member, inactive) and a `household_role` (adult, child).
- **Household**: people at one address. The home `location` (geography point) lives here.
- **User**: a login account at one church, linked to exactly one Person.
- **Role**: a named set of permission keys, per church. Defaults: Church admin (all permissions), Staff, Care team, Member.
- **UserRole**: grants a Role to a User.
- **Permission**: a key from the fixed catalogue in code (`manage_users`, `view_audit_log`, …).
- **AuditEvent**: append-only record of an important admin action (permission changes, deletions, settings changes).
- **MinistryLeadership**: makes a User a leader of one Ministry; leaders manage its groups and teams.

## People and organization
- **Tag** / **Tagging**: church-defined labels on people.
- **CustomField**: a church-defined attribute on people (text, number, date, yes/no, select, multi-select); values live in `people.custom_fields`.
- **Touchpoint**: one meaningful contact with a person (note, call, visit, text, email, prayer follow-up, form submission, workflow message). The person timeline and "no contact in N days" read these. *Sensitive* touchpoints hide their text from people without prayer access.
- **PersonImport**: an uploaded CSV of people, its column mapping, and results.
- **DuplicateDismissal**: staff decided two people are different.
- **Merged person**: a Person folded into another (`merged_into`); hidden everywhere.
- **Segment**: a saved filter over people (all/any of a list of conditions), reused as audiences and report scopes.
- **Coverage gap**: households with no active group within the church's coverage radius.
- **Ministry**: an organizational area (Kids, Worship, Hospitality).
- **Group** / **GroupMembership**: a community group people belong to (small group, Bible study, connection group), with leaders, a meeting schedule, capacity, and a location.
- **Team** / **TeamMembership** and **Position**: serving units within a ministry (Worship band; vocals, drums).
- **Task** and **Project**: staff work and ideas on a board (idea, to do, in progress, done).

## Scheduling, events, courses
- **WorshipService**: a recurring weekly service time (e.g. "Sunday 9am"). Nothing is named `Service`.
- **ServiceOccurrence**: one dated instance of a worship service.
- **PositionNeed**: how many people a position needs at a service (each week) or an event (each date).
- **Assignment**: a person scheduled to a position at a service or event occurrence (pending, accepted, declined).
- **PositionQualification**: who may serve in a position (none listed = anyone on the team).
- **Blockout**: dates a person can't serve.
- **Candidates / auto-fill**: suggested volunteers for an open spot, and filling open spots with the best ones (never emailed until a leader sends requests).
- **Conflict**: someone scheduled twice on the same local day, or scheduled while blocked out.
- **Event**, **EventOccurrence** (one date), **Registration** (a person, and their party size, on a date: confirmed, waitlisted, cancelled; with day-of check-in).
- **Waitlist**: bookings past capacity, promoted oldest-first when seats free up.
- **Course**, **CourseOffering** (one run with a leader, dates, capacity), **CourseSession** (one class meeting), **Enrollment** (enrolled, waitlisted, withdrawn, completed), **SessionAttendance** (present at a session). Never `Class`.
- **AttendanceCount**: the headcount for one service occurrence (a total, an optional breakdown by the church's categories, and first-time guests). "Online" is the online category; the rest are in person.
- **Attendance**: one person checked in at a service (`first_time` on their first ever).
- **SpecialSunday**: a church-marked unusual Sunday (Back to school, Friend day), keyed by name across years.
- **Special day**: any date that shifts attendance: Easter (computed), the holidays gem's weekends, and SpecialSundays.
- **AttendanceForecast**: the stored forecast for one service occurrence (expected, low–high range, online split, and the factors that produced it), frozen when the service starts.
- **Forecast factor**: one step of the forecast (baseline, trend, special day, last year) with its effect in people.
- **Forecast accuracy**: frozen forecasts compared with the actual counts: mean error and how often the actual landed in the range.

## Member area
- **Member area**: `/me`, where signed-in people see their schedule, events, classes, groups, household, and church updates.
- **Announcement** ("church update"): a post on the member area home page.
- **GroupJoinRequest**: a member asking to join a group; a leader approves or declines.
- **Account setup link**: the emailed link (staff invitation or self-claim) that lets a known person set a password.

## Pathways and automation
- **Pathway**: a church's ordered stages (default Connect → Grow → Serve).
- **PathwayStage**: one stage, with segment-style rules for reaching it and a "stuck after N days" limit.
- **PathwayPlacement**: where a person is now and since when (`entered_at`).
- **PathwayTransition**: one move (placed, forward, back); the history and the event workflows trigger on.
- **Stuck**: longer in a stage than its limit without moving on (never the last stage).
- **Volunteer load**: how heavily someone serves (weeks in a row, per week, teams, declines, weeks since served), rated underused / healthy / elevated / at risk.
- **Workflow**: an automation with a trigger, optional entry conditions, and ordered steps. It's draft, active or paused. Staff edit the draft; publishing freezes it into a version.
- **WorkflowVersion**: a published, numbered copy of a workflow's definition. Every run finishes on the version it started with.
- **Trigger**: what starts a run.
  - Events: person created, form submitted, tag added, group joined, pathway stage changed, first visit.
  - Checked each morning: missed N weeks, and N days before or after a date.
- **Step**: one action in a workflow: send email, wait, if/else (with yes and no branches), add or remove a tag, add to a group, create a task, notify staff, update pathway stage, add to a campaign, or an AI-drafted email.
- **WorkflowRun**: one person going through one version. Its status is active, waiting, completed, exited, cancelled or failed.
- **WorkflowStepExecution**: one step of one run, unique per run and step, so a step never happens twice.
- **MessageDraft**: a message a workflow wrote for one person, waiting in the **approval queue** until staff send it or decide not to.
- **AiRequest**: a logged AI call: the prompt, the reply, token counts and the purpose.
- **CampaignExtraRecipient**: someone a workflow added to a campaign that hasn't gone out yet.
- **Form**: a form staff build and anyone can fill in at `/f/:slug` (draft, published, closed). Its *purpose* is general or prayer request; event registration and benevolence intake purposes come later.
- **FormField**: one question: type, required, choices, where the answer goes (`maps_to`, e.g. `person.email`, `household.address`, `prayer_request.body`), whether it's sensitive, and a show/hide rule.
- **Show/hide rule**: conditions on earlier answers (all or any) that decide whether a question appears.
- **FormSubmission**: one set of answers (sensitive ones encrypted) with its status (received, reviewed, archived) and the person it was linked to.
- **Starter forms**: the Connect card and Prayer request drafts every church begins with.
- **Insight**: something that needs attention, found by a nightly check (overdue task, volunteer at risk, guest with no follow-up, unfilled Sunday spots, and so on).
  - It has a kind, subject, severity, title and numbers, and a suggested link.
  - Each has an audience: a permission, plus the people it belongs to directly.
  - It's open, snoozed, resolved (done or cleared) or dismissed. It closes itself when the situation clears.
- **DailyBrief**: one staff member's ranked insights for the day, with a short AI-written summary, or the rule-ranked list when AI is off. It can be emailed at 6am on request.
- **Report tool**: a fixed, read-only, church-scoped metric (pathway funnel, group connection, attendance over time, volunteer coverage, and so on) that checks the user's permission. The AI can only get numbers by calling these.
- **ReportConversation / ReportMessage**: a question to the report assistant and its answer, with the tool calls behind the answer and any figures that couldn't be traced to them.
- **SavedReport**: the tool calls behind an answer or a metric. Re-running gives fresh numbers without AI, and it can be pinned to the dashboard.

## Communications and web
- **SectionDefinition**: a reusable building block. Its Liquid produces MJML for email (or HTML for the web, in Phase 10), and it has a schema of settings and optional repeatable blocks. The built-in sections live in `app/sections/email` and are installed per church.
- **EmailTemplate**: an ordered list of sections, each with its own settings, plus a theme (colors, font). Every template gets a footer with the church's name, postal address and unsubscribe links.
- **EmailTopic**: a kind of email people can choose to get. It either goes to everyone unless they opt out, or only to people who opt in.
- **EmailPreference**: one person's choice for one topic.
- **Campaign**: a template sent to a segment on a topic. It moves from draft to scheduled, sending, sent or cancelled. The compiled HTML is saved when sending starts.
- **Delivery**: one recipient of one campaign. It carries the delivery status, opens, clicks and the unsubscribe token.
- **Suppression**: an address the church must not email.
  - Hard bounces, complaints and manual entries for all topics block every email, including system email.
  - Unsubscribes stop campaigns only, either for every topic or for one.
- **Integration**: a church's connection to an outside service (Postmark, Amazon SES, Mailchimp). Credentials are encrypted.
- **WebhookEvent**: a provider notification, stored exactly as it arrived, so it can be replayed.
- **Site**: a church's public website: a theme, the theme's settings (colors, fonts, logo, footer), an optional custom layout, and pages. It's served at `<subdomain>.<sites domain>` and on verified custom domains. Visitors see nothing until the site is put live.
- **SiteDomain**: a church's own domain for its site. It's pending until DNS points at us (a CNAME, or A records for a bare domain), then verified; one verified domain is the main address. Verified domains get HTTPS automatically.
- **Theme**: one of the built-in looks (modern, classic, minimal): a layout, a stylesheet, and default settings.
- **Page**: an ordered list of sections with a draft and a published version. Visitors only see the published one.
- **PageRevision**: a snapshot on each publish (the last 20), which can be restored as the draft.
- **SectionDefinition** (web): a building block for pages: Liquid that produces HTML plus a settings schema. Built-in ones can be edited in advanced mode (then they're "customized" and never overwritten by updates) or reset. Churches can also create custom ones.
- **SocialAccount**: a Facebook Page or Instagram business account the church can post to. It's connected, needs reconnecting, or disconnected, and its token is encrypted.
- **SocialPost**: text, an optional link, and photos, going to one or more accounts. It's a draft, scheduled, publishing, published, partly failed, failed or cancelled. Event promos are drafted automatically when a public event is published.
- **SocialPostTarget**: one post going to one account, which publishes at most once. It can be pending, publishing, published, failed, or unknown (it might have posted: a person checks), and it can have its own caption for that network.
- **Content calendar**: scheduled and published posts by day, plus upcoming public events that don't have a post yet.

## Care and giving
- **PrayerRequest**: a request for prayer with a visibility (pastoral staff, prayer team, shared) and status (active, answered, archived).
- **PrayerAssignment**: a prayer team member praying for a request.
- **BenevolenceCase**: a request for financial help for a person and their household.
  - Statuses: submitted, under review, approved, denied, fulfilled.
  - It records the kind of need and the requested and approved amounts. Its summary, circumstances and decision note are encrypted.
  - It comes from the public "Request financial help" form or from staff. Every time someone opens it, the audit log records it.
- **BenevolenceApproval**: one approver's decision (approve with an amount, or deny).
  - Above the church's threshold, a case needs the church's number of approvals (1 or 2) from people not handling it.
  - Any deny denies the case.
- **BenevolenceNote**: an encrypted note on a case.
- **BenevolenceDisbursement**: a payment for an approved case: amount, date, method, payee and fund. Once payments reach the approved amount, the case is fulfilled.
- **Policy flags**: warnings on a case, computed over a rolling 12 months for the household or person: over the church's limit, repeat requests, another open case, needs extra approval.
- **Fund**: where money goes. It's either synced from the giving platform or added here; benevolence funds are the ones offered for payments.
- **Donation**: one gift, synced and read-only, in integer cents with a currency. It's matched to a person automatically, manually, or not at all (ignored).
- **DonorLink**: "this platform donor is this person", learned from matches, so future gifts match themselves.
- **Review queue**: gifts no one could be matched to, one card per donor.
- **GivingSyncRun**: one pass of pulling donations, by webhook, the nightly reconciliation, or "Sync now".
