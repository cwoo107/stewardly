# Church websites in production: domains and automatic HTTPS

Church websites are served by the same Rails app on two kinds of hosts:

- `<subdomain>.<SITES_DOMAIN>`, e.g. `grace.stewardly.site`. This always works.
- Custom domains a church connects, e.g. `www.gracechurch.org`. These are served once they're verified.

The admin app stays on `<subdomain>.<APP_DOMAIN>`. The sites domain is deliberately a different registrable domain, so pages that run church-written Liquid can't read admin cookies.

## Environment

| Variable | Example | Purpose |
|---|---|---|
| `APP_DOMAIN` | `stewardly.app` | Admin app and platform console |
| `SITES_DOMAIN` | `stewardly.site` | Built-in site addresses (wildcard DNS `*.stewardly.site` → the proxy) |
| `SITES_CNAME_TARGET` | `domains.stewardly.site` | What church `www` records CNAME to (an A/AAAA record pointing at the proxy) |
| `SITES_APEX_IPS` | `203.0.113.10,203.0.113.11` | The proxy's public IPs, for bare domains, which can't CNAME |
| `TLS_ASK_TOKEN` | a long random string | Optional shared secret for the TLS check below |

## How a church connects a domain

1. **Add the domain:** a church admin adds `www.gracechurch.org` under Website → Addresses.
2. **Point DNS at us:** they add a CNAME `www → domains.stewardly.site`. For a bare domain they add A records pointing to `SITES_APEX_IPS`.
3. **Verification:** `SiteDomainVerificationJob` checks DNS every hour for 7 days. The admin can also click "Check now". Once the DNS matches, the domain is marked verified and becomes the site's main address.
4. **Certificate:** the first HTTPS request for the domain makes the proxy ask the app whether it may get a certificate. It then gets one from Let's Encrypt automatically.

## The TLS proxy

Kamal's `kamal-proxy` issues certificates only for hostnames listed in `deploy.yml`. It can't handle domains added at runtime, so run a TLS proxy with on-demand certificates in front of the app. Caddy is the simplest:

```caddyfile
{
	on_demand_tls {
		# 200 = allowed, anything else = refused (TlsChecksController)
		ask http://app:3000/internal/tls/allowed?token={$TLS_ASK_TOKEN}
	}
}

# Admin app, platform console, and built-in site addresses (wildcard certificates
# need a DNS challenge; on-demand certificates per host also work).
https:// {
	tls {
		on_demand
	}
	reverse_proxy app:3000 {
		header_up X-Forwarded-Proto https
	}
}
```

`GET /internal/tls/allowed?domain=<host>&token=<TLS_ASK_TOKEN>` returns 200 for:

- the app domain;
- church subdomains of the app domain and the sites domain;
- the CNAME target;
- verified custom domains.

Any other host gets 404. That's how nobody can make us request certificates for names we don't serve. Keep this endpoint reachable only from the proxy, and set `TLS_ASK_TOKEN`.

Also set `config.assume_ssl = true` (TLS ends at the proxy) and `config.force_ssl = true` in `config/environments/production.rb`.

## Hosts allowed by Rails

`config.hosts` in production allows:

- the app domain and its subdomains;
- subdomains of the sites domain;
- any host `SiteDomain.verified_host?` approves (cached for a minute).

A request for an unknown host is blocked before it reaches the app.
