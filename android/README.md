# Secret KFS Android

Android Studio project for the Secret KFS shop. This first version is a lightweight Android WebView app that loads the live store and supports JavaScript, local storage (cart persistence), Android back navigation, external WhatsApp/email/maps links, loading feedback, and an offline retry screen.

## Build
1. Install Android Studio (Ladybug or newer) with JDK 17 and Android SDK Platform 35.
2. Open this `android/` directory in Android Studio.
3. Allow Gradle sync to finish.
4. Run on an Android device or emulator.

To build an APK: **Build → Build Bundle(s) / APK(s) → Build APK(s)**.

- Application ID: `com.secretkfs.shop`
- Version: `1.0.0`
- Minimum Android: 6.0 (API 23)
- Store URL: https://webdimeler.github.io/secret/

## Before public release
- Test checkout and external links on physical Android devices.
- Add a branded launcher icon and splash screen.
- Configure a signed release key securely; never commit keystore files/passwords.
- Review Google Play's current WebView and user-data policies.
- This is a connected storefront shell, not a full offline/native rewrite.
