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
- `AttendanceCount` (headcounts per occurrence), `Attendance` (individual check-ins): Phase 4.

## Member area
- **Member area**: `/me`, where signed-in people see their schedule, events, classes, groups, household, and church updates.
- **Announcement** ("church update"): a post on the member area home page.
- **GroupJoinRequest**: a member asking to join a group; a leader approves or declines.
- **Account setup link**: the emailed link (staff invitation or self-claim) that lets a known person set a password.

## Pathways and automation
- `Pathway`, `PathwayStage`, `PathwayPlacement`
- `Workflow`, `WorkflowVersion`, `WorkflowRun`, `WorkflowStepExecution`
- **Form**: a form staff build and anyone can fill in at `/f/:slug` (draft, published, closed). Its *purpose* is general or prayer request; event registration and benevolence intake purposes come later.
- **FormField**: one question: type, required, choices, where the answer goes (`maps_to`, e.g. `person.email`, `household.address`, `prayer_request.body`), whether it's sensitive, and a show/hide rule.
- **Show/hide rule**: conditions on earlier answers (all or any) that decide whether a question appears.
- **FormSubmission**: one set of answers (sensitive ones encrypted) with its status (received, reviewed, archived) and the person it was linked to.
- **Starter forms**: the Connect card and Prayer request drafts every church begins with.
- `Insight`

## Communications and web
- `EmailTemplate`, `Campaign`, `Delivery`, `Suppression`
- `Site`, `Theme`, `Page`, `SectionDefinition`
- `SocialAccount`, `SocialPost`

## Care and giving
- **PrayerRequest**: a request for prayer with a visibility (pastoral staff, prayer team, shared) and status (active, answered, archived).
- **PrayerAssignment**: a prayer team member praying for a request.
- `BenevolenceCase`, `BenevolenceDisbursement`
- `Donation`, `Fund`
