# PakPocket architecture

## Product boundary

PakPocket is local-first. Calculations and personal finance records work offline; network-backed services (billing, ads, analytics, crash reporting, optional backup, and remote rate updates) are adapters and must never be required to open local records. No login, CNIC, card storage, or contact permission is required for the free core.

## Structure and dependency rule

Features live under `lib/features/<feature>/{data,domain,presentation}`. Presentation depends on domain abstractions; data implements those abstractions. Shared infrastructure lives under `core`, reusable widgets under `shared`. Widgets must not issue SQL or contain rate tables.

- State: Riverpod Notifier/AsyncNotifier providers.
- Navigation: GoRouter stateful shell with five persistent branches.
- Data: SQLite through repository implementations; SharedPreferences only for small preferences.
- Calculations: typed `Calculator<Input, Result>` domain services. Input validation throws a human-readable `CalculationException`.
- Changing rates: typed configurations with version, effective date, update date, and source label. Formula services consume configurations supplied by repositories.
- External SDKs: Analytics, Crashlytics, AdMob, Play Billing, notifications, export, and backup sit behind interfaces and are introduced in later phases with no-op development implementations.

## Database entities and relationships

`Category 1—N Transaction`; `Category 1—N Budget`; `LedgerPerson 1—N LedgerTransaction`; `Vehicle 1—N FuelEntry`. Calculator history tables are independent immutable snapshots and store the configuration version used. `SubscriptionStatus` is a single cached entitlement row; Play remains the source of truth. UserSettings are lightweight preferences rather than financial records.

Deletion order is child-first and foreign keys are enabled. Amounts are validated as non-negative at both domain and database boundaries. A migration is required for every schema change.

## Free and Premium entitlements

Free includes every basic calculator, local expense/income records, monthly totals, limited active ledgers, payment tracking, theme/localization, and basic history. Premium gates advanced analytics, budgets, recurring transactions, exports/reports, saved calculations, year comparisons, unlimited ledgers, reminders, solar ROI, history/trends, multiple vehicles, backup, and ad removal. Gating uses semantic `PremiumFeature` values rather than UI booleans. Prices are always supplied by Play Billing product details.

## Rate configuration

Static formulas are pure Dart. Tax slabs, tariffs, fuel/electricity prices, solar assumptions, and metal prices are versioned data. Bundled reviewed defaults provide offline behavior; a future signed remote update may replace them. Screens show the effective/updated dates and source. When a current volatile rate is unavailable, the user must enter it manually.

## Planned packages

The implemented foundation uses `flutter_riverpod`, `go_router`, `sqflite`, `shared_preferences`, `intl`, `path`, Flutter localization, `in_app_purchase`, and `pdf`. Later phases add official Firebase Analytics/Crashlytics, Google Mobile Ads and consent, local notifications/timezone, richer charting, sharing/file-picker packages, and connectivity only when their feature is implemented.

## Play policy and privacy risks

- Financial features require precise estimate disclaimers and must not imply government, FBR, utility, or religious authority endorsement.
- Play Billing must be used for digital Premium access, with restore, entitlement verification, acknowledgement, and account-hold/grace handling.
- Ads require Families/target-audience review, consent flows where applicable, test IDs in development, and no disruptive placements during financial entry.
- Data Safety must accurately disclose analytics, diagnostics, ads, purchases, optional backup, and deletion/export behavior.
- Notification permission is requested contextually on supported Android versions. Contacts, SMS, call logs, storage, location, and CNIC are not requested by default.
- Release signing secrets stay outside version control. Privacy policy, terms, support contact, data deletion, and subscription disclosures are required before release.

## Phase checklist

- [x] Project, architecture boundaries, navigation, Material 3 theme, English/Urdu RTL, SQLite schema, preference persistence, dashboard, and settings foundation.
- [x] Calculator domain models, configurations, screens, boundary tests, rate metadata, manual volatile inputs, and estimate disclaimers.
- [x] Expense/income repositories and flows; seeded categories; monthly summaries; Udhaar people, transactions, due status, and partial/full repayments.
- [x] Premium monthly budgets, category analytics, Play product/entitlement boundary, restore flow, isolated ad policy, privacy/terms pages, PDF reports, and CSV exports.
- [ ] Category-specific budgets, recurring transactions, advanced filters, production purchase-token backend verification, AdMob/consent, and Firebase analytics/crash adapters.
- [x] Contextual local notification permission, per-type preferences, Udhaar due reminders, global local-data search, full JSON export, and confirmed financial-data deletion.
- [ ] Remaining reminder schedulers, full screen-by-screen Urdu copy review, accessibility audit, recurring transactions, and backup opt-in.
- [ ] Full QA matrix, adaptive icon/splash, signed AAB process, store listing, policy forms, and release review.
