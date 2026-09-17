# AdMob app-ads.txt authentication design

## Context

Coordit is linked to App Store listing `6804425048`, but AdMob app authentication fails because the production host returns HTTP 401 for `/app-ads.txt`. The existing support and privacy pages are public routes on the same Cloud Run service.

## Design

Add `GET /app-ads.txt` to the public Express application before authenticated API routes. It returns the single AdMob-authorized seller record as UTF-8 `text/plain`:

```text
google.com, pub-7471774017488090, DIRECT, f08c47fec0942fa0
```

The route performs no authentication, database access, logging, redirects, or feature-flag checks. Existing APIs and Apple IAP configuration remain unchanged.

## Verification

Add an HTTP-level regression test that proves an unauthenticated request receives status 200, the `text/plain` content type, and the exact seller record. Run the focused backend health suite, type checking, and build. After deployment, verify the public HTTPS response, request an AdMob authentication refresh, and enable rewarded ads only after AdMob accepts the app configuration.
