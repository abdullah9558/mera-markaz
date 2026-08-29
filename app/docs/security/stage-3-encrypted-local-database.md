# Stage 3 — Automatic Encrypted Local Database

**Implemented:** 2026-08-27  
**Target validated:** Samsung SM-G991B, Android 15

## Result

- Local financial data is encrypted automatically without asking the user to create or store a recovery key.
- A random 256-bit installation database key is generated once and wrapped by a non-exportable Android Keystore AES-256-GCM key.
- Only the wrapped key envelope is stored in app-private preferences.
- `sqflite_sqlcipher 3.4.1` is pinned and SQLCipher 4.x protects the complete SQLite database.
- Guests and signed-in accounts use the same encrypted installation database while repository owner isolation remains unchanged.
- Optional per-account recovery remains separate and is only relevant to future encrypted cloud backup/new-device restore.

## Existing database migration

1. Detect the exact plaintext SQLite header.
2. Refuse to treat a non-plaintext file as migratable; wrong keys fail closed.
3. Checkpoint the legacy database and count every application table.
4. Create a separate encrypted temporary database using SQLCipher `ATTACH` and `sqlcipher_export()`.
5. Preserve `user_version`.
6. Reopen with the generated password, run `PRAGMA quick_check`, and compare every table count.
7. Atomically move the original aside and the encrypted database into place.
8. Reopen and verify the live encrypted database.
9. Restore the original on any swap/verification failure.
10. Delete plaintext rollback/temp artifacts after verified success.

## Physical verification

- An unsupported plaintext `PRAGMA rekey` attempt failed before swap; the original remained unchanged.
- The corrected `sqlcipher_export()` migration completed and the app reopened successfully.
- The live database header was verified as random ciphertext instead of `SQLite format 3`.
- The separate plaintext safety copy and migration rollback were removed after verification.
- Static analysis passed, all 73 existing tests passed, and the Android debug APK built successfully.

## Limitations and next work

- Uninstalling the app removes the Android Keystore key; local data is then intentionally unrecoverable.
- Rooted/compromised unlocked devices and data visible on screen remain outside this protection boundary.
- Receipt image files, plaintext exports, profile SharedPreferences, notification privacy, and cloud sync require subsequent stages.
- Add an Android instrumentation migration fixture for CI, including wrong-key, interrupted swap, and large-database performance cases.
