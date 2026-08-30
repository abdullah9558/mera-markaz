# Feedback SMTP setup

The Android app sends feedback to `/api/feedback`. The API delivers it to
`muhammadabdullah589@gmail.com` using Gmail SMTP. SMTP credentials must only be
stored in Vercel environment variables and must never be committed to Git.

## Gmail setup

1. Enable 2-Step Verification on the Google account used as the sender.
2. Open Google Account → Security → App passwords.
3. Create an app password named `Mera Markaz Feedback`.
4. Copy the generated 16-character password. Do not use the normal Gmail password.

## Vercel environment variables

In Vercel, open the Mera Markaz website project, then Settings → Environment
Variables. Add these:

- `SMTP_HOST` = `smtp.gmail.com`
- `SMTP_PORT` = `465`
- `SMTP_USER` = the Gmail address used to send messages
- `SMTP_PASS` = the 16-character Gmail app password
- `FEEDBACK_TO` = `muhammadabdullah589@gmail.com`

Redeploy the website after saving the variables.

## Android endpoint

The app defaults to `https://mera-markaz.vercel.app/api/feedback`.

If the deployed Vercel domain is different, build with:

`flutter run --dart-define=FEEDBACK_API_URL=https://YOUR-DOMAIN/api/feedback`

Use the same `--dart-define` when building the Play Store AAB.
