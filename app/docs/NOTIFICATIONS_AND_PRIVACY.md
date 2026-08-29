# Notifications and privacy controls

PakPocket requests Android notification permission only when the user enables a reminder. Every reminder category is off by default and stored independently. Udhaar entries with a due date schedule a 9:00 AM local reminder only when Udhaar reminders are enabled. Inexact scheduling avoids requesting exact-alarm access.

Financial data remains local by default. Privacy & Data provides a free JSON export containing transactions, seeded categories, budgets, ledgers, saved calculations, vehicles, and fuel entries. Delete All Financial Data removes user financial records in a foreign-key-safe transaction while retaining app preferences, system categories, and verified purchase entitlement.

The app does not request contacts, SMS, call logs, CNIC, location, or broad storage access. Exports are written to application document storage. A later sharing/file-picker flow should use Android's scoped document APIs rather than broad filesystem permissions.

## Optional online Markaz AI

Local Markaz AI answers remain on the device. Signed-in users may separately consent to online Markaz AI, which sends Google Gemini only a limited aggregate financial summary for personalized financial assistance. The summary can include monthly income, expenses, balance, savings, category totals and budgets, aggregate Udhaar amounts, and savings-goal progress.

The online summary excludes passwords, authentication tokens, email address, user ID, phone number, provider credentials, contact names, notes, receipts, profile photos, and complete or individual transaction records. Guest mode never calls Gemini. Users can withdraw online-AI consent from the Markaz AI privacy dialog without deleting local conversation history.

Gemini responses are informational and may be incomplete or inaccurate. They are not financial, tax, legal, or religious advice.

## Google Play Data Safety preparation

Before publishing, the Data Safety form must reflect the production implementation: optional processing by Google Gemini for app functionality/personalized financial assistance, local-only guest mode, excluded secrets and complete records, consent withdrawal, and the app's actual transport, retention, and deletion behavior. Final declarations must be confirmed after authenticated-user and App Check enforcement tests pass.
