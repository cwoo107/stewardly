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
| `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD` | none | The platform's own mail delivery, used when a church hasn't connected a provider |
| `GEOCODER_LOOKUP` | `nominatim` | Geocoding provider (use a commercial one such as `mapbox` or `google` in production) |
| `GEOCODER_API_KEY` | none | Provider API key |
| `GEOCODER_CONTACT_EMAIL` | `geocoding@example.com` | Sent in the User-Agent (required by Nominatim) |
| `OLLAMA_URL` | `http://localhost:11434` (development) | The self-hosted Ollama server all AI goes through |
| `AI_MODEL` | `gpt-oss:20b` (development) | The Ollama model. It must support tool calling for the report assistant (gpt-oss, Llama 3.1, and Qwen 2.5 do) |
| `AI_THINK` | `low` (development) | How much a reasoning model thinks first (`low`/`medium`/`high`). Unset it for models without reasoning |
| `OLLAMA_API_KEY` | none | Only if the Ollama server sits behind an authenticating proxy |

### AI in development
1. Install and start Ollama: the macOS app (`open -a Ollama`), or `brew install ollama && ollama serve`.
2. Pull the model: `ollama pull gpt-oss:20b` (about 13 GB). For a smaller download, use `ollama pull qwen2.5:7b` (about 4.7 GB) and start the app with `AI_MODEL=qwen2.5:7b AI_THINK= bin/dev`.
3. Restart `bin/dev`, so the web server *and* Sidekiq pick up the settings.
4. Turn AI on for the church in Settings. The seeded Grace church already has it on.

Every AI call is logged as an `AiRequest` and counts toward the church's monthly limit.

What uses AI:
- the dashboard's daily brief (Refresh);
- Reports → Ask (answers run in Sidekiq);
- workflow AI drafts in the approval queue;
- "Polish with AI" on social posts.

## Demoing over the internet (Cloudflare quick tunnels)
To show the app to people without deploying it:

```sh
bin/demo                    # demos Grace (stop your bin/dev first; bin/demo runs its own)
DEMO_CHURCH=hope bin/demo   # another seeded church
```

It opens two free Cloudflare quick tunnels, with no account needed: one for the church's staff app and member area, and one for its public website. It prints both `https://….trycloudflare.com` addresses and the logins, then runs `bin/dev`. Links, redirects and emails use the tunnel addresses.

Keep in mind:
- The addresses are random and change on every run.
- Anyone with a link can reach the app, and the seeded logins use the password `password`. Share links only with people you trust, and press Ctrl-C when you're done.
- Viewers can't open developer tools: detailed error pages, `/rails/mailers`, `/rails/info` and `/letter_opener` are hidden on tunnel addresses. They still work on `localhost` for you.
- Only the chosen church is reachable. The platform console and other churches aren't tunneled.
- Requires `cloudflared` (`brew install cloudflared`).
- If a link says "can't be found" on your Mac only, your Mac cached an early DNS miss. Flush it with `sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder`, or open the link in another browser. `bin/demo` waits for Cloudflare to publish both addresses before printing them, to avoid this.

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
