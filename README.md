# Stewardly

A multi-tenant church management platform (Rails 8, PostgreSQL + PostGIS, Hotwire, Tailwind, Sidekiq + Redis).

## Requirements
- Ruby (see `.ruby-version`)
- PostgreSQL 17 with PostGIS 3
- Redis 7

## Setup
```sh
bin/setup          # installs gems, creates and seeds the database, starts bin/dev
```

`bin/dev` runs the web server, the Tailwind watcher, and Sidekiq (`Procfile.dev`). Use it rather than
`rails assets:precompile && rails s`: precompiled files in `public/assets` hide new CSS and JavaScript in
development (`bin/rails assets:clobber` removes them).

Sent email appears at http://localhost:3000/letter_opener, and every email template can be previewed at
http://localhost:3000/rails/mailers. Sidekiq runs recurring jobs from `config/schedule.yml` (the hourly reminder sweep).

The member area is at http://grace.localhost:3000/me (`member@grace.test` / `password`).

| URL | What | Sign in |
| --- | --- | --- |
| http://localhost:3000 | Platform console (+ `/sidekiq`) | `platform@stewardly.test` / `password` |
| http://grace.localhost:3000 | Grace Community Church (demo) | `admin@`, `staff@`, `care@`, `member@grace.test` / `password` |
| http://hope.localhost:3000 | Hope Fellowship (second tenant) | `admin@hope.test` / `password` |

## Environment
| Variable | Default | Purpose |
| --- | --- | --- |
| `APP_DOMAIN` | `localhost` | Churches live at `<subdomain>.APP_DOMAIN` |
| `REDIS_URL` | `redis://localhost:6379/1` | Sidekiq + Action Cable (`maxmemory-policy noeviction`) |
| `REDIS_CACHE_URL` | `redis://localhost:6379/2` | Rails cache (`allkeys-lru` in production) |
| `SIDEKIQ_CONCURRENCY` | `5` | Sidekiq threads |
| `MAIL_DOMAIN` | app domain (`stewardly.test` locally) | Mail is sent from `no-reply@MAIL_DOMAIN` as the church's name |
| `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD` | none | Production mail delivery (until Phase 6's delivery providers) |
| `GEOCODER_LOOKUP` | `nominatim` | Geocoding provider (use a commercial one such as `mapbox` or `google` in production) |
| `GEOCODER_API_KEY` | none | Provider API key |
| `GEOCODER_CONTACT_EMAIL` | `geocoding@example.com` | Sent in the User-Agent (required by Nominatim) |

## Tasks
```sh
bin/rails churches:create NAME="New Life" SUBDOMAIN=newlife TIME_ZONE="Pacific Time (US & Canada)" \
  ADMIN_FIRST_NAME=Ada ADMIN_LAST_NAME=Park ADMIN_EMAIL=ada@newlife.test ADMIN_PASSWORD=...
bin/rails platform_admins:create NAME="Ops" EMAIL=ops@example.com PASSWORD=...
```

In a console, tenant models need a church: `ActsAsTenant.with_tenant(Church.find_by!(subdomain: "grace")) { Person.count }`.

## Tests and CI
JavaScript system specs (drag and drop, the segment builder) use Cuprite and need Chrome or Chromium installed. `HEADLESS=0` shows the browser.
```sh
bundle exec rspec
bin/ci             # RuboCop, RSpec, bundler-audit, importmap audit, Brakeman
```

See `docs/decisions.md` and `docs/domain.md`.
