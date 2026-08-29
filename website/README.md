# Mera Markaz website

Official product, user-guide, privacy, support, data-safety and account-deletion website for the Mera Markaz Android app.

## Local setup

The website expects the Flutter app next to it:

```text
E:\Projects\Pakistani App
E:\Projects\mera-markaz-site
```

Install once with `npm install`. Start the website with `npm run dev`, then open the local address printed in the terminal.

## Keep the website aligned with the app

Every `npm run dev` and `npm run build` automatically runs `npm run sync:app`. It reads the current version and feature folders from the Flutter project in `../app` and copies the official app logo, thumbnail and any files placed in `app/assets/screenshots`.

For continuous asset/version syncing while both projects are open, run `npm run dev:sync` in a second terminal. Changes to Dart, YAML or app assets will refresh the website data automatically. The website dev server will then update the browser.

Product claims, privacy wording and instructions require human review when app behaviour changes. Use the release checklist in `docs/APP-TO-WEBSITE-CHECKLIST.md` for every public app release.

## Publish

Run `npm run build` before deployment. In Vercel, import the repository and set the Root Directory to `website`. Use the public homepage URL in the Google Play developer profile, the `/privacy` URL for the Privacy Policy field, and `/account-deletion` for the account-deletion URL.
