# PakPocket

Pakistan-first personal finance and everyday utility app built with Flutter and Material 3.

## Current milestone

Phases 1–5 core: feature-first architecture, local SQLite persistence, full-screen English/Urdu RTL, session-gated email/password, Google and Facebook authentication with explicit offline access, six calculators, expense/income management, Udhaar repayments and reminders, Premium/Play boundaries, budgets, analytics, PDF/CSV/JSON exports, global search, and privacy deletion controls. See [architecture](docs/ARCHITECTURE.md), [authentication configuration](docs/AUTH_CONFIGURATION.md), [rate sources](docs/RATE_SOURCES.md), and [Play configuration](docs/PLAY_CONFIGURATION.md).

## Run checks

```text
flutter pub get
dart format .
flutter analyze
flutter test
flutter build apk --debug
```

Production secrets and IDs are intentionally not committed. Online authentication falls back safely to an explicit offline session until Firebase, Google, and Facebook are configured. Play products use build-time IDs and still require server-side token verification before release. AdMob and consent SDK activation remain disabled until production accounts, policy declarations, and environment configuration are supplied.
