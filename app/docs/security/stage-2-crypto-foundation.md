# Stage 2 — Cryptographic Foundation Implementation Record

**Implementation date:** 2026-08-27  
**Status:** Foundation implemented and Android Keystore validated on a physical device; recovery UX confirmation remains a gate item before Stage 3.

## Implemented

- Pinned `cryptography 2.9.0`.
- AES-256-GCM envelopes with 96-bit random nonces, 128-bit tags, schema version, and key version.
- Strict envelope validation and fail-closed authentication errors.
- Canonical AAD binding owner, record type, opaque record ID, revision, schema version, and key version.
- HKDF-HMAC-SHA-256 purpose separation for local database, records, blobs, backups, indexes, and recovery wrapping.
- Random 256-bit UMEK generation.
- First-party Android Keystore bridge using a non-exportable AES-256-GCM key, randomized encryption, and validated opaque aliases.
- Separate 256-bit recovery secret with a four-byte typo-detection checksum.
- Recovery KEK derivation with a random 256-bit salt and domain-separated HKDF context.
- Device-wrapped and recovery-wrapped UMEK metadata persistence. Raw UMEK and recovery secret are not persisted.
- Guest and duplicate-enrollment rejection.
- Removal and rollback behavior for partially created device wrapping keys.

## Deliberate exclusions

- The existing SQLite database remains plaintext during Stage 2. Stage 3 performs the atomic SQLCipher migration.
- No Firebase upload is enabled. Recovery-wrapped keys will be uploaded only after owner-scoped rules and enrollment authorization are implemented.
- Biometric UI currently remains an application gate. Binding Keystore use to BiometricPrompt/CryptoObject needs a deliberate recovery-friendly UX and physical-device tests before activation.
- No automatic enrollment occurs on sign-in. A recovery key must be shown once and confirmed by the user; silently enrolling would risk unrecoverable data.

## Verification completed

- Static analysis: clean.
- Crypto tests: AES-GCM round trip, unique nonces, tampered ciphertext, wrong key, wrong AAD, malformed nonce, and HKDF purpose separation.
- Enrollment tests: device unlock/recovery equivalence, recovery secret not persisted, altered recovery key rejection, guest rejection, and duplicate rejection.
- Android debug APK: compiled successfully with the native Keystore bridge.
- Physical Android 15 validation on Samsung SM-G991B: temporary Keystore AES-256-GCM key generation, AAD-bound wrap, unwrap, constant-time equality verification, and deletion passed on 2026-08-27.

## Gate before Stage 3

1. Add and approve the one-time recovery-key display and confirmation UX.
2. Apply the selected policy: biometric re-unlock after the app leaves the active session/auto-lock period; recovery remains available.
3. Exercise app restart, confirmed recovery, deletion, and reinstall/key-loss behavior through that UI.
4. Complete the source/native dependency review of `sqflite_sqlcipher 3.4.1`.
5. Re-run the full suite and retain a release rollback plan.

Stage 3 must not start until these items are accepted.
