# Authentication configuration

PakPocket now has a session gate with email/password registration and login,
password reset, Google login, Facebook login, logout, and an explicit offline
session. The checked-in build deliberately contains no production credentials.
Until Firebase is configured, online buttons show a configuration message while
**Continue offline** remains available.

## 1. Connect Firebase

1. Create a Firebase project and register Android package
   `pk.pakpocket.pakpocket`.
2. Install the Firebase CLI and FlutterFire CLI, sign in, then run
   `flutterfire configure` from this project.
3. Use the generated Firebase options in `lib/main.dart`, or install the
   downloaded `google-services.json` in `android/app` and enable the Google
   Services Gradle plugin.
4. In Firebase Console > Authentication > Sign-in method, enable
   **Email/Password** and **Google**.
5. Add the development and Play App Signing SHA-1 and SHA-256 fingerprints to
   the Android app in Firebase. Download refreshed Android configuration after
   changing fingerprints.

## 2. Configure Facebook

1. Create a Meta developer app and add the Facebook Login product.
2. Enable Facebook in Firebase Authentication and enter the Meta app ID and
   app secret.
3. Copy Firebase's OAuth redirect URI into the Facebook Login allowed redirect
   URIs.
4. Register package `pk.pakpocket.pakpocket`, the launcher activity, and the
   debug/release/Play key hashes in the Meta app.
5. Follow `flutter_facebook_auth` Android setup to add the Facebook app ID,
   client token, and callback scheme as Android string resources and manifest
   metadata. Do not commit real secrets.

## 3. Release checks

- Replace debug signing with a protected upload keystore.
- Restrict Firebase API keys to the expected Android package and signing
  certificates.
- Test new account, returning account, reset email, Google, Facebook, app
  restart, token restoration, logout, revoked-provider access, and offline mode
  on a physical device.
- Update the Privacy Policy and Google Play Data Safety declaration for account
  identifiers, email address, provider profile data, diagnostics, retention,
  and deletion.
- Decide whether financial records remain device-wide or become isolated per
  account before enabling multi-user use on shared devices.

