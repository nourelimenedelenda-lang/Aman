# ResQRoad

ResQRoad is a Flutter road-safety prototype organized by feature and Clean Architecture layers.

## Architecture

`lib/features/` contains the app features. Each feature keeps its UI in `presentation/`, business rules and repository contracts in `domain/`, and platform or persistence implementations in `data/`. The `incidents` feature owns the incident entity and repository contract shared by reporting, activity, home, and emergency flows. `core/` contains shared theme and widgets; `shell/` composes the feature screens.

```text
lib/
  core/
  features/
    activity/{data,domain,presentation}/
    authentication/{data,domain,presentation}/
    driving/{data,domain,presentation}/
    emergency/{data,domain,presentation}/
    home/{data,domain,presentation}/
    incidents/{data,domain,presentation}/
    location/{data,domain,presentation}/
    profile/{data,domain,presentation}/
    reporting/{data,domain,presentation}/
    shell/presentation/
```

## Data and location

- Current coordinates come from the device location service through `geolocator`. The app requests foreground location permission and reports disabled services or denied permission in the UI.
- On Android, driving mode runs the motion sensors and GPS in an Android location foreground service with an ongoing notification and CPU wake lock, so it can continue while the screen is locked or the app is in the background. Notification permission must be granted. Stop the session from the app; force-stopping the app or manufacturer battery restrictions can still stop monitoring. Persistent background driving monitoring is not implemented on iOS.
- A four-second evidence window feeds the prototype confidence score `100 × (0.40A + 0.25G + 0.25V + 0.10S)`. Impact sound is not enabled, so `S` is currently zero. Scores 40–69 are flagged in the dashboard; scores of 70 or higher start a 15-second countdown in the Android foreground service, including while the app is backgrounded or the screen is locked. The driver can cancel with “I’m safe”; if they do not, ResQRoad opens the dialer for the first saved emergency contact. The user must confirm the call in the phone app; ResQRoad does not place calls automatically or contact emergency services.
- Location access can be checked and managed from Profile > App settings, including links to the device's app-permission and location-service settings. The current UI language is English.
- A human-readable address is requested from the platform geocoder. If reverse geocoding is unavailable, the UI keeps the GPS coordinates and marks the address unavailable.
- Maps use interactive OpenStreetMap tiles via `flutter_map`, display the captured position and reported accuracy, and include map attribution. The public OSM tile service has a usage policy and is suitable only while request volume and usage comply with that policy; choose a hosted tile provider for a production deployment.
- Incident reports and emergency contacts/settings are stored in the signed-in user's Firestore account. Incident photos stay on the device and are not uploaded to Firebase Storage; synced reports on another device do not include their photos.
- Sign-in uses Firebase Authentication (email/password and Google). Firestore rules in `firestore.rules` restrict account documents and reports to their owner. Firebase Storage is not used.

## Prototype limitations

Driving-mode sensors are real device readings, but impact detection and confidence thresholds are an unvalidated prototype. Emergency countdowns are local; dialer launch does not confirm that a call was placed. The app does not place emergency calls automatically, dispatch responders, or provide a live safety service. Raw high-frequency sensor readings are not uploaded; confirmed/detected incident records are saved to the user's incident history.

## Firebase setup (Android)

The Android app is linked to Firebase project `aman-d8248`. Enable authentication and Firestore in Firebase Console:

1. In **Authentication > Sign-in method**, enable **Email/Password** and **Google**.
2. Create the default **Firestore Database** in the region appropriate for your users/data-residency needs.
3. Add the Android app's SHA-1 and SHA-256 signing fingerprints in **Project settings > Your apps**. Get the local debug fingerprints from `cd android; .\gradlew signingReport`. Download the updated `google-services.json` into `android/app/` after enabling Google sign-in.
4. From the project root, deploy the owner-only rules with `firebase deploy --only firestore:rules`.

Firestore rules must be deployed before database reads/writes work. The app does not use Firebase Storage. Android is the configured platform; iOS and web require their own Firebase app configuration before sign-in and Firestore can work.

## Development

```sh
flutter pub get
flutter analyze
flutter test
```
