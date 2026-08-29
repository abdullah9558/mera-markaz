# Mera Markaz — Stage 1 Security and Architecture Audit

**Audit date:** 2026-08-27  
**Audited project:** `E:\Projects\Pakistani App`  
**Scope:** Existing Flutter/Android application only. No encryption, storage, schema, or synchronization code was modified during this stage.

## Executive decision

The application is not ready for encrypted cloud synchronization yet. It has a sound offline-first, repository-based structure, but its local database, profile preferences, AI history, receipt OCR, and exported reports are currently stored as plaintext. Firebase is used for Authentication, App Check, and optional Gemini access; Firestore and Firebase Storage are not implemented.

The required implementation should proceed only in gated stages. The first engineering stage must introduce and validate the user master encryption key (UMEK), Android Keystore wrapping, recovery wrapping, and encrypted local database migration. Cloud synchronization must not begin until migration, wrong-key, tamper, recovery, and rollback tests pass.

### Highest-risk findings

| Severity | Finding | Consequence |
|---|---|---|
| Critical | `pakpocket.db` is ordinary `sqflite` SQLite | Financial records are readable from a copied database on a compromised/rooted/debuggable device or backup. |
| High | JSON, CSV, and PDF exports are plaintext | Reports can remain in app storage, backups, shares, or temporary destinations without encryption. |
| High | Profile data and guest identity are plaintext SharedPreferences | Personal data and session metadata are not cryptographically protected. |
| High | Receipt OCR text and image paths are plaintext | Merchant, totals, and extracted receipt content can be exposed. |
| High | AI conversation history is plaintext locally | Financial questions and answers can reveal sensitive context. |
| High | Biometric authentication is only a UI gate | It is not bound to a Keystore key and does not protect database decryption. |
| Medium | Reminder notification bodies include amount and person name | Financial information may appear on the lock screen. |
| Medium | Delete/account lifecycle is local-only and incomplete | Cloud deletion, reauthentication, preference cleanup, and cryptographic erasure are absent. |

## Threat model

### Assets

- Transaction, budget, balance, debt, vehicle, fuel, tax, zakat, property, solar, and savings data.
- Receipt images, OCR text, merchant names, and totals.
- Profile information and authentication identity.
- AI questions, answers, consent, and the limited summary sent to Gemini.
- UMEK, purpose-derived keys, device wrapping keys, recovery material, and encrypted backups.

### Relevant attackers and failures

- A person who obtains a copied database, app backup, exported file, or cloud document.
- A rooted or otherwise compromised device and malicious software with filesystem access.
- A user of another Firebase account attempting cross-user reads or writes.
- A stolen unlocked device or sensitive lock-screen notification.
- A backend operator or cloud breach exposing Firestore/Storage contents.
- Network interception; Firebase SDK traffic is expected to use TLS, but application-layer encryption is still required for stored financial content.
- Accidental corruption, interrupted migration, replayed writes, sync conflicts, lost devices, lost recovery keys, and maliciously modified ciphertext.

### Explicit limitations

- Client-side encryption cannot protect data while it is displayed on an unlocked compromised device.
- It cannot make a rooted device or malicious accessibility service trustworthy.
- Metadata needed for synchronization—owner UID, opaque record IDs, type, version, timestamps, deletion status, and ciphertext size—remains visible unless separately concealed.
- Gemini must receive the user-approved limited summary in plaintext inside Google’s protected service request; end-to-end encryption cannot cover data actively processed by the model.
- Losing every authorized device and the recovery key must make encrypted data unrecoverable. There must be no hidden server-side bypass.

## 1. Current database architecture

- Flutter feature-first codebase using Riverpod, repositories, and a central `AppDatabase`.
- Local persistence uses `sqflite` and the file `pakpocket.db`, currently schema version 6.
- Tables are owner-scoped with logical owner strings such as `account:<firebaseUid>` and `guest:<randomId>`.
- Guest data can be claimed when creating a new account or discarded when signing into an existing account.
- Current migrations are additive schema migrations. There is no encryption migration journal, rollback marker, cloud revision, durable sync queue, UUID migration, or tombstone architecture.

This separation between repositories and SQLite is a useful migration seam. Repositories should remain the application-facing API while encrypted local storage and synchronization are introduced beneath them.

## 2. Current Firebase architecture

- Firebase project: `mera-markaz`.
- Android application ID/package: `pk.pakpocket.pakpocket`.
- Implemented: Firebase Core, Firebase Authentication, Firebase App Check, and Firebase AI Logic/Gemini.
- Debug builds use the App Check debug provider; release builds use Play Integrity.
- Not implemented: Cloud Firestore, Firebase Storage, Cloud Functions, Firestore Security Rules, Storage Rules, emulator tests, or cloud backup/sync collections.
- No Firebase Analytics or Crashlytics dependency was found.

Firebase currently has no copy of the financial database. Adding Firestore later must not upload legacy plaintext records.

## 3. Authentication architecture

- Email/password, Google, and Facebook authentication are implemented through Firebase Authentication.
- Email verification is requested for password accounts.
- Firebase UID is the stable account identity and must be used in Firestore ownership paths/rules.
- Guest identity is a locally persisted random owner ID and is not a Firebase identity.
- New-account registration can claim the current guest records; signing into an existing account discards the guest session data.
- Missing security lifecycle work: recent-login reauthentication, complete account deletion, device authorization/revocation, encrypted-key enrollment, recovery-key setup, and cloud cryptographic erasure.

The UMEK must never be derived from a Firebase password or provider token. Provider changes and password resets must not change the data-encryption key.

## 4. Sensitive field inventory

The following existing data is sensitive and must be encrypted locally and before cloud upload:

- `transactions`: amount, category, date, description, payment method, notes, source relationships.
- `budgets`: amount, category, and period.
- `ledger_people`: names and phone numbers.
- `ledger_transactions`: amount, paid amount, due dates, description, notes, and status.
- Electricity, tax, solar, and property calculations and inputs.
- Vehicles, fuel entries, odometer values, maintenance descriptions/costs/dates/notes.
- Receipt drafts: image path/reference, merchant, total, and raw OCR text; image bytes require encrypted blob storage.
- Net-worth accounts: names, types, and balances.
- Zakat assets, deductions, nisab values, and calculated amounts.
- Savings-goal names, targets, contributions, notes, and dates.
- Recurring-transaction amounts, descriptions, and schedules.
- Reminder titles, schedules, and record references.
- AI conversation titles, prompts, answers, and timestamps.
- Profile name, phone, photo reference, and other personally identifying fields.

Only the minimum synchronization envelope should remain plaintext: schema/key version, opaque UUID, owner UID in the security path, encrypted record type code if feasible, revision, timestamps, tombstone flag, nonce, tag, and ciphertext.

## 5. Current plaintext exposure

- All SQLite tables and metadata are plaintext.
- Profile JSON, biometric preference, guest owner/session ID, and selected preferences are stored in SharedPreferences.
- AI conversations are stored in plaintext SQLite.
- Receipt OCR and local image paths are stored in plaintext SQLite; receipt images are ordinary files.
- Full JSON export, CSV export, and PDF reports are human-readable files written to application documents storage.
- Database file names, record relationships, sequential integer IDs, row counts, and timestamps expose behavioral metadata.
- Dashboard “privacy mode” visually hides some figures but does not encrypt storage and is not applied globally.
- There is no Android screenshot/recents protection such as `FLAG_SECURE` for sensitive screens.
- Reminder notifications can reveal an amount and person name on the lock screen.

## 6. Current key storage

There is no financial-data encryption key today. `local_auth` performs a biometric-only UI check at startup when enabled, but it does not unlock a non-exportable Android Keystore key, wrap a UMEK, or gate database decryption.

App Check tokens and Firebase credentials are SDK-managed and are not substitutes for encryption keys. No hardcoded Gemini API secret was found; Firebase AI Logic is used.

## 7. Logging, analytics, and network review

- No Analytics or Crashlytics SDK is configured.
- No custom HTTP client, certificate bypass, `badCertificateCallback`, or trust-all implementation was found.
- Firebase SDK traffic provides transport encryption.
- The only relevant debug output found reports an App Check debug-token request error; logs must never include a token, UMEK, recovery key, plaintext record, or AI summary.
- Online Gemini is optional, limited to authenticated users with explicit consent, and uses a reduced financial summary. That summary still contains sensitive aggregates and some category/goal labels, so the consent and privacy disclosure are necessary.

Before release, add a central redacting logger and tests that reject sensitive field names/values in production logs. Do not add analytics events containing financial values, user text, categories, record IDs, or recovery/device state.

## 8. Current backup and export flows

- Existing JSON, CSV, and PDF flows are exports, not secure backups.
- They have no encryption, authentication tag, password protection, key wrapping, tamper detection, manifest signature/MAC, atomic creation, or guaranteed temporary-file cleanup.
- No `.mmb` encrypted backup and no restore workflow exists.
- No cloud backup/sync exists.

Existing plaintext export can remain only as an explicit high-friction user export with a clear warning and secure share lifecycle. It must never be labeled an encrypted backup.

## 9. Migration risks

- In-place encryption failure could destroy the only copy of user data.
- Database-key loss or an invalid wrapped UMEK would make all records unrecoverable.
- Guest-to-account conversion during migration can duplicate, orphan, or misattribute records.
- Integer IDs and relationships must be mapped to stable opaque UUIDs without breaking foreign keys.
- Receipt files and exported artifacts live outside database rows and need separate inventory/migration.
- An interrupted dual-write or cloud bootstrap can produce partial encrypted state.
- Ciphertext expansion and SQLCipher migration can increase storage and startup time.
- Downgrading to an older app could expose or corrupt the new database.
- A wrong key, corrupt header, or authentication-tag failure must never trigger creation of a blank database over the original.

Required migration method: preflight available space and key recovery; close DB; create an encrypted temporary database; copy and verify every table/relationship/count and selected canonical hashes inside one controlled migration; fsync/close; atomically rename only after verification; retain a protected rollback copy until the new database has opened successfully multiple times; then securely remove the legacy copy where the platform permits. Record migration phases without storing secrets.

## 10. Proposed cryptographic implementation

### Record and envelope cryptography

- `cryptography` **2.9.0**, pinned. The optional `cryptography_flutter` plugin was evaluated during Stage 2 and removed because the application already has a small first-party Android Keystore bridge and the plugin added unnecessary Kotlin build/supply-chain surface.
- AES-256-GCM authenticated encryption.
- Unique 96-bit (12-byte) cryptographically random nonce for every encryption. Never construct nonces from timestamps, counters, record IDs, or revisions.
- 128-bit authentication tag.
- HKDF-HMAC-SHA-256 for purpose-separated subkeys.
- Canonical, versioned additional authenticated data (AAD), for example: `appId | schemaVersion | keyVersion | ownerUid | recordType | recordUuid | revision`.
- Ciphertext envelope fields: `algorithm`, `schemaVersion`, `keyVersion`, `nonce`, `ciphertext`, `tag`, and AAD-bound metadata.

The `cryptography` package is cross-platform and exposes AES-GCM/HKDF primitives; its random nonce facility must be backed by a secure random source. Pin exact versions, review changelogs, generate an SBOM, and verify release artifacts. Do not implement AES or HKDF manually.

### Local database encryption

The least disruptive candidate is `sqflite_sqlcipher` **3.4.1**, which is API-compatible with `sqflite` and uses SQLCipher 4.x. However, its publisher is not verified on pub.dev. Treat this as a security-review gate, not an automatic dependency choice:

1. Pin the package version and transitive native SQLCipher version.
2. Review package source, native build configuration, release history, maintainers, and known vulnerabilities.
3. Confirm SQLCipher PRAGMA defaults, page authentication, KDF parameters, backup behavior, and Android ABI support.
4. Run physical database inspection and performance tests on supported Android versions.
5. If it fails review, use a maintained native SQLCipher integration behind the existing database abstraction instead.

SQLCipher protects the complete local database. Field-level AES-GCM remains necessary for Firestore documents and encrypted backup payloads.

## 11. Key hierarchy

```text
Random 256-bit User Master Encryption Key (UMEK)
├── HKDF(info="mera-markaz/local-db/v1")       -> local SQLCipher key material
├── HKDF(info="mera-markaz/record/v1")         -> Firestore record AEAD key
├── HKDF(info="mera-markaz/blob/v1")           -> receipt/blob AEAD key
├── HKDF(info="mera-markaz/backup/v1")         -> .mmb payload AEAD key
└── HKDF(info="mera-markaz/index/v1")          -> optional blind-index key

UMEK copies are stored only as wrapped ciphertext:
├── Device-wrapped UMEK: Android Keystore AES-GCM wrapping key
└── Recovery-wrapped UMEK: recovery-key-derived KEK + random salt/context
```

- Generate the UMEK with a CSPRNG; never derive it from UID, password, provider token, PIN, or biometric data.
- Use separate HKDF salt/context and immutable purpose labels; never reuse a derived key for another purpose.
- Do not store raw keys in SharedPreferences, SQLite, Firestore, logs, crash reports, Dart source, or backups.
- Keep decrypted key bytes in memory only as long as needed and overwrite buffers where practical; Dart/runtime copies mean guaranteed zeroization cannot be claimed.
- Increment `keyVersion` for rotation and support read-old/write-current during controlled migration.

## 12. Proposed Firestore schema

Use owner-scoped paths and opaque UUID document IDs:

```text
users/{uid}
  publicProfile/{profileDoc}                 # only deliberately non-sensitive/minimal fields
  crypto/deviceEnvelopes/{deviceId}          # wrapped UMEK, key version, status, timestamps
  crypto/recovery/{recoveryId}               # recovery-wrapped UMEK, salt, KDF/version metadata
  records/{recordUuid}                       # encrypted record envelope
  tombstones/{recordUuid}                    # opaque deletion metadata or encrypted tombstone
  syncState/{deviceId}                       # cursors/acknowledgements, no financial plaintext
  backupManifests/{backupUuid}               # encrypted manifest metadata
```

Recommended record document:

```text
ownerUid: <uid>                    # rules/ownership only
recordUuid: <opaque UUIDv4>
recordTypeCode: <minimal code>
schemaVersion: 1
keyVersion: 1
revision: <monotonic logical revision>
updatedAt: <server timestamp>
deleted: false
nonce: <base64>
ciphertext: <base64/bytes>
tag: <base64/bytes>
deviceId: <opaque authorized device ID>
```

Do not place descriptions, amounts, names, phone numbers, categories, schedules, OCR, or balances in document names, paths, indexes, or plaintext metadata. Large encrypted receipt blobs belong in Firebase Storage at an owner-scoped opaque path; Firestore stores only the encrypted blob envelope/reference.

## 13. Security Rules architecture

- Default deny all Firestore and Storage access.
- Require `request.auth != null` and `request.auth.uid == uid` for every owner path.
- Require App Check enforcement after verified metrics and provider testing.
- Validate immutable owner UID, allowed envelope fields, sizes, supported schema/key versions, UUID format, revision behavior, and server timestamps.
- Prevent clients from authorizing their own device envelope without an already-authorized-device or verified recovery flow.
- Storage rules must constrain owner path, content size/type, and immutable metadata; the server must never assume MIME type means plaintext is safe.
- Avoid broad collection-group access. If collection-group queries are needed, rules must still prove ownership from document fields and tests.
- Use the Firebase Emulator Suite to test cross-user reads/writes, unauthenticated access, field injection, oversized payloads, owner mutation, revoked devices, and malformed envelopes.

Rules enforce authorization, not confidentiality. Firestore must receive ciphertext even when rules are correct.

## 14. Recovery design

- At encryption enrollment, generate a separate high-entropy 256-bit recovery secret and display it once as grouped, checksummed text/QR with an explicit confirmation step.
- Derive a recovery KEK with HKDF-SHA-256 using a random per-user salt and fixed domain label because the generated recovery secret already has high entropy.
- If the product later accepts a human-created backup password, use a memory-hard KDF such as Argon2id with per-backup random salt and device-benchmarked parameters; do not reuse the high-entropy recovery-key parameters.
- Store only the recovery-wrapped UMEK, salt, nonce, tag, algorithm/KDF version, and verification metadata in Firebase.
- Never upload the recovery secret, plaintext UMEK, or a reversible hint.
- Recovery must require Firebase reauthentication plus the recovery secret. Rate limiting and audit events should be added where a trusted backend is available.
- Generate a new recovery secret only through a deliberate rotation that rewraps the same UMEK (or performs full key rotation). Warn that the old recovery secret stops working.

## 15. Local encrypted backup design

Define a versioned `.mmb` container, not a renamed ZIP:

```text
magic + containerVersion
public header: algorithms, KDF metadata, random salts/nonces, ciphertext lengths
encrypted manifest: app/schema/key versions, record counts, attachment inventory, timestamps
encrypted payload: canonical records and encrypted attachment bytes
AEAD authentication tag(s)
```

- Default backup encryption uses a key derived from the UMEK backup subkey.
- For portable restore on a device without the UMEK, offer explicit recovery-key or password-wrapped backup-key mode.
- Authenticate header fields as AAD; reject any altered, truncated, unsupported, or oversized file before modifying the live database.
- Restore into a temporary encrypted database, validate everything, then atomically swap.
- Do not export raw database keys or plaintext attachment names.
- Clean temporary files after success/failure and use Android’s Storage Access Framework/share sheet rather than broad storage permissions.

## 16. Device authorization design

- Generate a random opaque `deviceId` on enrollment; do not use hardware serial, advertising ID, phone number, or Firebase installation ID as a public identifier.
- Each device creates a non-exportable Android Keystore AES-256-GCM wrapping key.
- Wrap the UMEK on-device and store only the wrapped envelope in app-private storage and the owner-scoped cloud device envelope.
- Optional biometric lock must bind key use to Android Keystore user authentication through BiometricPrompt/CryptoObject; biometrics never become key material.
- Provide a device list with label, added/last-seen timestamps, and status. Labels should be user-editable and avoid unnecessary hardware detail.
- Revocation prevents future sync/key-envelope retrieval. It cannot erase keys already extracted from a fully compromised device; communicate that limitation.
- New-device enrollment must use an authorized existing device or recovery flow, plus recent Firebase reauthentication.
- App reinstall without recovery must not silently create a new UMEK when encrypted cloud data already exists.

## 17. Dependency plan

Proposed additions, only after approval and package review:

| Purpose | Candidate | Gate |
|---|---|---|
| AEAD/HKDF/Argon2id | `cryptography 2.9.0` | Pin, review changelog/SBOM, known-answer tests. |
| Platform crypto acceleration | Not currently added | Reconsider only if measured performance requires it; the Stage 2 build showed the extra plugin was unnecessary. |
| Encrypted SQLite | `sqflite_sqlcipher 3.4.1` | Unverified publisher: source/native dependency security review required. |
| Firestore | current compatible `cloud_firestore` | Pin against current Firebase BOM/plugin set; emulator/rules tests. |
| Encrypted blob transport | current compatible `firebase_storage` | Add only when receipt/blob sync ships. |
| Stable record IDs | direct pinned `uuid` dependency | UUIDv4 CSPRNG verification; do not rely on transitive dependency. |
| Keystore bridge | small first-party Android platform channel | Prefer auditable native code over generic secret storage for biometric-bound wrapping. |

Do not install a dependency merely because it advertises “encryption.” Verify primitives, nonce behavior, platform implementation, key storage, maintenance, publisher provenance, license, native binaries, and failure semantics first.

## 18. Database migration plan

1. Add non-sensitive migration-state storage and block app downgrade.
2. Generate/restore the UMEK and verify device/recovery envelopes before touching data.
3. Create encrypted DB beside the legacy DB; never mutate the only copy in place.
4. Create the new schema with stable UUIDs, encryption/key versions, revisions, and tombstone/sync tables.
5. Copy rows in dependency order while mapping old integer IDs to UUIDs.
6. Copy receipt attachments into encrypted files and replace plaintext paths with opaque references.
7. Verify table counts, foreign-key integrity, financial aggregate invariants, canonical test hashes, and ability to reopen with the correct key.
8. Prove wrong-key and tampered-page failures do not overwrite either database.
9. Atomically switch to the encrypted DB and mark the migration committed.
10. Retain a protected rollback copy until repeated successful starts and user-visible verification; then remove legacy plaintext and known temporary/export artifacts where possible.
11. Only after local encryption is proven, bootstrap encrypted record-level cloud sync.

During transition, avoid indefinite dual-write. If temporary dual-write is unavoidable, make it bounded, journaled, idempotent, and never upload the plaintext side.

## 19. Required tests

### Cryptography

- AES-GCM known-answer, round-trip, unique nonce, wrong key, wrong AAD, changed tag/ciphertext/nonce, and truncated-envelope tests.
- HKDF purpose-separation and key-version tests.
- Recovery-wrap and device-wrap positive/negative tests.
- Assert secrets never serialize into preferences, databases, Firestore payloads, logs, or backups.

### Database and migration

- Upgrade populated databases from every supported legacy version.
- Crash/restart at each migration phase; low-storage and corrupted-row cases.
- Referential integrity and financial aggregate equivalence before/after migration.
- Physical inspection that recognizable names, notes, phone numbers, OCR, and amounts are absent from DB/WAL/SHM/temp files.
- Wrong-key open must fail closed and preserve the database.

### Firebase and rules

- Emulator tests for owner access, cross-user denial, unauthenticated denial, revoked-device denial, invalid fields/versions/sizes, owner mutation, and Storage paths.
- App Check metrics before enforcement; debug, Play internal-testing, and release signing identities.
- Verify cloud documents/blobs contain no financial plaintext.

### Sync and recovery

- Offline create/update/delete; retries; duplicate delivery; tombstones; clock skew; concurrent multi-device edits; deterministic conflict policy; key rotation in progress.
- New-device enrollment from an existing device and from recovery.
- Lost recovery key, invalid recovery key, revoked device, reinstall, provider change, and Firebase password reset.

### Backup/privacy/performance

- `.mmb` round-trip, tamper/truncation/wrong password or recovery key, zip-bomb/oversize resistance, temporary cleanup, and atomic restore.
- Notification redaction, screenshot/recents behavior, clipboard expiry, and log scanning.
- Startup, migration, sync, large-dataset, receipt encryption, memory, and battery benchmarks on low/mid/high Android devices.

Existing functional tests remain valuable but do not currently cover these security properties.

## 20. Incremental implementation stages and gates

### Stage 1 — Audit (this document)

**Complete.** No cryptographic/storage changes. Approval required to continue.

### Stage 2 — Crypto foundation and device/recovery enrollment

Implement reviewed AES-GCM/HKDF envelopes, random UMEK, native Android Keystore wrapping, recovery wrapping, versioning, and destructive negative tests.  
**Gate:** known-answer, tamper, wrong-key, key-loss, and reinstall/recovery tests pass; no raw key persists.

### Stage 3 — Encrypted local database migration

Introduce reviewed SQLCipher integration, atomic migration, UUID mapping, encrypted attachments, and rollback.  
**Gate:** migration matrix and physical plaintext scans pass; measured performance is acceptable.

### Stage 4 — Privacy hardening

Protect notifications, screenshots/recents, logs, temp files, exports, clipboard, and complete delete/account lifecycle.  
**Gate:** privacy regression tests pass and user-facing claims match behavior.

### Stage 5 — Encrypted record model and sync engine

Add Firestore/Storage, encrypted envelopes, durable outbox, revisions, tombstones, idempotency, conflict UX, and offline behavior.  
**Gate:** no plaintext cloud payload; offline/multi-device/conflict tests pass.

### Stage 6 — Rules, App Check, device authorization, and recovery

Deploy owner-scoped default-deny rules, emulator suite, App Check enforcement, device enrollment/revocation, and recovery UX.  
**Gate:** adversarial rules tests and all provider/recovery/device scenarios pass.

### Stage 7 — Encrypted `.mmb` backup and restore

Implement authenticated versioned container, portable recovery/password modes, atomic restore, and malformed-file defenses.  
**Gate:** round-trip and destructive negative tests pass across supported versions/devices.

### Stage 8 — Release validation

External security review, dependency/SBOM and vulnerability review, Play signing/Integrity validation, performance/accessibility/localization QA, recovery drills, privacy policy and Data Safety update.  
**Gate:** signed release checklist and rollback plan approved.

## Security claim guidance

Do not market this architecture as “zero knowledge,” “military-grade,” or proof that data is impossible to access. Accurate wording after implementation and verification is: financial records are encrypted on the device and before cloud storage; keys are protected with device and user-controlled recovery mechanisms; limited, consented summaries may be processed by Gemini; and metadata plus data displayed on a compromised unlocked device are not fully concealed.

## Stage 1 stop gate

Per the requested architecture process, implementation stops here. Before Stage 2, approve:

1. The threat model and acknowledged limitations.
2. The UMEK/device-wrap/recovery-wrap hierarchy.
3. The `cryptography` package choice.
4. A formal accept/reject review of `sqflite_sqlcipher` or selection of a native alternative.
5. The irreversible recovery rule: without an authorized device or recovery key, encrypted data cannot be recovered.

No dependency, schema, encryption, synchronization, backup, or Firebase Rules change should be merged before this gate is accepted.

## Primary implementation references

- Android cryptography guidance: <https://developer.android.com/privacy-and-security/cryptography>
- Android biometric authentication and cryptographic operations: <https://developer.android.com/identity/sign-in/biometric-auth>
- Dart `cryptography`: <https://pub.dev/packages/cryptography>
- Flutter platform implementation: <https://pub.dev/packages/cryptography_flutter>
- SQLCipher project: <https://www.zetetic.net/sqlcipher/>
- Candidate Flutter SQLCipher package: <https://pub.dev/packages/sqflite_sqlcipher>
- Firestore Security Rules: <https://firebase.google.com/docs/firestore/security/get-started>
- Firestore Emulator rules testing: <https://firebase.google.com/docs/firestore/security/test-rules-emulator>
- Firebase App Check for Flutter: <https://firebase.google.com/docs/app-check/flutter/default-providers>
