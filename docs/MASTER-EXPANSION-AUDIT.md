# Mera Markaz Master Expansion Audit

This audit implements Phase 0 of `MERA MARKAZ.docx`. It records the existing application before expansion and controls subsequent dependencies.

## Existing architecture

- Flutter Material 3 with Riverpod.
- Local-first, owner-scoped SQLCipher database (`AppDatabase`, schema v9) with incremental migrations.
- A canonical `transactions` table already links fuel, Udhaar and recurring activity through sources/foreign keys.
- Firebase Authentication supports email, Google and Facebook. Persistent guest sessions can be claimed or discarded.
- Automatic local encryption plus optional encrypted Firebase sync, authorized devices and recovery keys.
- English/Urdu, RTL, light/dark/system themes, privacy masking, global search, notifications, PDF/CSV exports and App Check.
- Existing modules: income/expenses, budgets, Udhaar, savings, recurring transactions, timeline, vehicles/fuel, tax, electricity, solar, property, Zakat, analytics, OCR, voice entry, Net Worth and Markaz AI.

## Thirty-feature classification

| # | Feature | State | Required work |
|---|---|---|---|
| 1 | Smart Home | Partial / redesign | Modular order, Safe to Spend, Pakistan Today, upcoming commitments and drill-downs |
| 2 | Pakistan Live | Missing | Shared repository, cache, freshness, sources and dashboard |
| 3 | PKR Exchange Center | Missing | Conversion, favourites, history and alerts |
| 4 | Freelancer Income | Missing | Foreign-income records linked once to canonical transactions |
| 5 | Pakistan Tax Center | Partial | Remote/versioned configs, comparison and persisted snapshots |
| 6 | Salary Breakdown | Partial | Persist components/deductions and canonical salary linkage |
| 7 | Salary Day | Missing | Suggested allocation workflow; never move money automatically |
| 8 | Bill Center | Partial | Extend recurring/reminders with bills, history, attachments and statuses |
| 9 | Electricity Intelligence | Partial | Readings, actual bills, history and actual/estimate labels |
| 10 | Appliance Estimator | Missing | Appliance scenarios and interactive breakdown |
| 11 | Electricity to Solar | Partial | Link history to configurable recommendation |
| 12 | Solar ROI | Missing | Installation and performance history, ROI/payback |
| 13 | Gold/Silver Center | Missing | Sourced values, history and watchlists |
| 14 | Zakat Intelligence | Partial | Asset composition, annual history/reminders and metal linkage |
| 15 | Gold Holdings | Missing | Quantity/purity/purchase/value linked to Net Worth/Zakat |
| 16 | Net Worth | Partial | History, allocation and integrated assets/liabilities |
| 17 | Inflation Calculator | Missing | Historical CPI and labelled future scenarios |
| 18 | Savings Purchasing Power | Missing | Savings linkage and projections |
| 19 | Loan/Financing | Missing | Fixed/variable/KIBOR, amortization and comparison |
| 20 | Economic Dashboard | Missing; depends on #2 | Period charts over shared Pakistan data |
| 21 | Watchlists | Missing; depends on #2 | CRUD, pause, cooldown and crossing state |
| 22 | Economic Alerts | Missing; depends on #21 | Deduplicated notifications |
| 23 | Daily Brief | Missing | Consolidated useful morning/evening brief |
| 24 | Markaz AI | Partial | Broaden deterministic/local query coverage |
| 25 | Receipt/Bill Scanning | Partial | OCR review exists; add bill fields/document types |
| 26 | Voice Entry | Partial | Improve Urdu/Roman Urdu structured parsing |
| 27 | Household Mode | Missing | Explicit per-record privacy and encrypted collaboration |
| 28 | Committee Tracker | Missing | Savings-circle schedules/reminders; tracking only |
| 29 | Advanced Udhaar | Partial | Installments, attachments, statements and explicit sharing |
| 30 | Calendar/Safe Spend/Health | Partial | Reserve/planned-savings model and full calendar views |

## Reuse and overlap decisions

- Bills extend reminders/recurring records and link paid items to one transaction; no second expense ledger.
- Freelancer and salary records reference one income transaction with stable source identifiers.
- Fuel, electricity, receipt and saving flows reuse existing linked transaction paths.
- Pakistan Live and the economic dashboard share one repository/cache; Feature 20 cannot precede Feature 2.
- Gold Center, holdings, Net Worth and Zakat share sourced rates and holding records.
- Watchlists and notifications share one threshold/deduplication engine.
- Timeline presents bills, salary, Udhaar, savings, installments and custom events.

## Database migration plan

Move v9 to v10 with additive tables only. Add Pakistan cache/history/favourites/watch conditions; bills/payments; foreign income/salary details; electricity readings/appliances; solar performance; gold holdings; Net Worth snapshots; financing scenarios; committee schedules; household privacy; notification inbox/deduplication; dashboard/widget configuration. Index owner/date/status/source lookups and update encrypted-sync allow-lists in the same phase. Preserve v1-v9 data and test every upgrade.

## Firebase, encryption and privacy impact

- Personal finance stays offline-first and SQLCipher-encrypted.
- New owner-scoped tables join encrypted sync; no plaintext financial documents enter Firestore.
- Public Pakistan indicators may be cached without user identity.
- Gemini keeps the consented limited-summary contract.
- Widgets/notifications default to masked/private. Logs and analytics exclude values, names, descriptions, keys and tokens.
- Household sharing requires separately scoped encrypted records, not broad public collections.

## Pakistan data-source and reliability plan

- SBP: exchange rates, policy rate, KIBOR and reserves.
- PBS: CPI/inflation.
- FBR/Finance Act: tax years and slabs.
- NEPRA/Government notifications: electricity tariffs and adjustments.
- OGRA/Government notifications: petroleum pricing.
- Gold/silver: a documented reliable provider when no official machine-readable feed exists, labelled accordingly.
- Store value, unit, source/reference, effective/retrieved times, previous value, config version and freshness.
- Cached/stale data is never labelled live; failed refresh keeps the saved timestamp/source.
- Use manual/event-driven refresh and conservative background intervals, never minute polling.

## Widget, notification and deep-link architecture

- Configurable widget families use small privacy-filtered snapshots; native receivers never open the encrypted database. Defaults mask amounts.
- A persisted notification inbox supports categories, private/detailed modes, quiet hours, actions and deduplication keys.
- Typed routes cover transaction creation, budgets, bills, Udhaar, savings, indicators, watchlists, Net Worth, Zakat and solar. Payloads contain route IDs, not sensitive display data, and validate ownership.

## Free/premium recommendation

Keep the product free. Privacy, encryption, security alerts, core records, backups/export/deletion, basic widgets and essential reminders remain free. Do not surface the dormant premium architecture. Any future paid cloud AI/deep analytics requires a separate decision.

## Dependency sequence and gates

`canonical events + source metadata + deep links` -> `Pakistan data/cache + notification inbox` -> `Smart Home` -> `Pakistan Live` -> `watchlists/alerts` -> `finance modules` -> `cross-feature intelligence` -> `widgets` -> `polish/QA`.

Each phase ends with formatting, analysis, focused and regression tests, migration validation, privacy review and Android build. No phase is complete while knowingly broken.
