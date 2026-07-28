# The Nuus — iOS

A native SwiftUI client for thenuus.com. Splash screen, then the latest
edition pulled from the same JSON the website uses.

No Mac required: builds run on a GitHub Actions macOS runner, and everything
else happens in App Store Connect in the browser.

## Layout

```
ios/
  project.yml                 XcodeGen spec — the .xcodeproj is generated, not committed
  make-icon.py                Renders the 1024x1024 App Store icon (no dependencies)
  TheNuus/
    TheNuusApp.swift          Entry point + splash/feed crossfade
    Model.swift               Edition and Story types
    NewsService.swift         Networking + offline cache
    Theme.swift               Colours shared with the website
    SplashView.swift
    FeedView.swift            Story list, pull-to-refresh, error/retry states
    SafariView.swift          In-app article reader
```

The app reads two public endpoints, already live:

- `https://thenuus.com/data/manifest.json` → `{ "dates": ["2026-07-26", ...] }`
- `https://thenuus.com/data/<date>.json` → `{ "date", "stories": [...] }`

No backend work is needed. When `fetch-news.js` publishes a new edition, the
app picks it up on next launch.

## What you need before submitting

1. **Apple Developer Program membership — $99/year.** Required for App Store
   distribution; there is no free path. Enrol at developer.apple.com.
2. **An App Store Connect API key** (Users and Access → Integrations → App Store
   Connect API). Download the `.p8` **once** — Apple never shows it again.
3. **A distribution certificate and provisioning profile** for
   `com.thenuus.app`.

## Repository secrets

Settings → Secrets and variables → Actions:

| Secret | What it is |
| --- | --- |
| `APPLE_TEAM_ID` | 10-character team ID, shown in the developer portal |
| `IOS_CERTIFICATE_P12` | Distribution cert as base64: `base64 -i cert.p12` |
| `IOS_CERTIFICATE_PASSWORD` | Password set when exporting the `.p12` |
| `IOS_PROVISIONING_PROFILE` | Profile as base64 |
| `ASC_KEY_ID` | API key ID |
| `ASC_ISSUER_ID` | API issuer ID |
| `ASC_PRIVATE_KEY` | The `.p8` file as base64 |

## Building

Actions → **iOS Build & Upload** → Run workflow.

Leave `upload` unchecked to compile only — this verifies the code without
needing any signing secrets, so it is worth running first. Tick `upload` to
archive, sign, and send the build to App Store Connect.

## App Review: the 4.2 problem

Guideline 4.2 (Minimum Functionality) rejects apps that are essentially a
website in a wrapper. A news reader is a common target, so the app is built to
answer that objection directly:

- Stories render as **native SwiftUI**, not a webview.
- The last edition is **cached to disk** and served when offline.
- Articles open in an **in-app Safari sheet** with Reader mode preferred.
- Native pull-to-refresh, error and retry states.

If it still gets rejected, the usual remedies are push notifications for the
daily edition, an archive browser using `manifest.json` (the data is already
there), and saving or sharing stories. Reply in Resolution Center rather than
resubmitting blind — Apple names the specific shortfall and it is usually
cheaper to address than to guess.

Set **Content Rights** to indicate third-party content, since the digest links
to external publishers, and expect an age rating of 12+ or 17+ for news.
