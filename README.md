# Mera Markaz

Mera Markaz is a Pakistan-first personal finance and utility application by Logivyre Labs. This repository contains both products:

- `app/` — Flutter Android application
- `website/` — public product, support, privacy and user-guide website

## Run the Android app

Open `app/` in Android Studio, select a connected Android phone and run `lib/main.dart`.

## Run the website

```powershell
cd website
npm install
npm run dev
```

The website synchronises the app version, feature modules and approved branding assets from `app/` whenever it starts or builds.

## Deploy only the website on Vercel

Import this repository in Vercel and set **Root Directory** to `website`. Vercel will build and deploy only the website; it will not compile or publish the Flutter application.

Never commit signing keystores, signing passwords, service-account files, API secrets, debug tokens or user databases.

