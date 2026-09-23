# Facebook and Instagram: the Meta app and App Review

Stewardly posts through **one Meta app owned by the platform**. Each church signs in with Facebook and grants that app access to its own Pages and Instagram accounts. Nothing works in production until the app has passed Meta's review.

## Environment

| Variable | Purpose |
|---|---|
| `META_APP_ID`, `META_APP_SECRET` | The platform's Meta app |
| `META_GRAPH_VERSION` | The Graph API version the adapter calls (default `v21.0`). Pin it, and re-check the adapter when you change it |

## Meta app setup

1. **Create the app.** At developers.facebook.com, create an app of type **Business**, and add **Facebook Login for Business** and **Instagram Graph API** (Instagram API with Facebook Login).
2. **Register the redirect URI:** `https://<APP_DOMAIN>/oauth/meta/callback`. This is the only one. Every church's connection returns here, carrying a signed state that names the church and user, and is then sent back to the church's own subdomain.
3. **Set the required URLs:**
   - **Privacy policy:** your public privacy policy.
   - **Deauthorize callback:** `https://<APP_DOMAIN>/oauth/meta/deauthorize`
   - **Data deletion request callback:** `https://<APP_DOMAIN>/oauth/meta/data_deletion`. It replies with a status URL and a confirmation code.
4. **App details:** add an app icon, a category, and contact email.
5. **Business Verification:** complete it for the company that runs Stewardly (Meta Business Settings → Security Center).

## App Review: permissions to request

Each permission needs a written use case and a screencast of the feature using it:

| Permission | Why Stewardly needs it |
|---|---|
| `pages_show_list` | List the Pages the person manages, so they can choose which to connect |
| `pages_read_engagement` | Read Page details and post links after publishing |
| `pages_manage_posts` | Publish, and schedule publishing of, the church's posts to its Page |
| `instagram_basic` | Read the linked Instagram business account (name, picture) |
| `instagram_content_publish` | Publish photos and carousels to the church's Instagram |
| `business_management` | Only if Pages are owned through Business Manager. Request it only if testing shows it's needed |

Before approval, only people with a role on the app (admin, developer, tester) can connect. Switch the app to **Live** once it's approved.

## Things churches need to know

- **Instagram:** it must be a **Business or Creator** account linked to the church's Facebook Page. Personal accounts can't be posted to.
- **Photos must be public:** Instagram needs at least one photo, and Meta downloads it from a public URL. Photos are served from the church's website address, so the sites domain must be publicly reachable.
- **Reconnecting:** tokens can stop working if someone changes their Facebook password or removes the app. A daily check (`SocialAccountCheckJob`) flags accounts that need reconnecting, and an insight tells staff.

## What still needs verifying

`Social::Providers::Meta` was written from my understanding of the Graph API, not checked against Meta's current documentation. Every call is marked `TODO(verify vendor docs)`. `spec/models/social/providers/meta_spec.rb` has pending examples to turn into real ones once each call has been checked against the pinned version:

- **Connecting:** the OAuth dialog, code exchange, and long-lived token exchange.
- **Accounts:** the `/me/accounts` fields, page tokens, and linked Instagram accounts.
- **Facebook posts:** feed, photo, and multi-photo posts (`attached_media`).
- **Instagram posts:** containers, carousels, `media_publish`, and permalinks. Meta may require polling a container until it's ready before publishing it.
- **Errors and checks:** error codes (190, `is_transient`), `/debug_token`, and the signed_request format of the two callbacks.
