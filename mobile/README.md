# CampusFix — Student Mobile App

A cross-platform (iOS + Android) Flutter app for **students** of the CampusFix / UEM–IEM
complaint-management system. It talks to the same Flask backend as the web dashboard
(`backend/`, served under `/campusfix/api`) and provides the full student experience:

- **Login** — OTP to your `@uem.edu.in` / `@iem.edu.in` email (primary), plus email + password
  sign-in / registration.
- **Report an issue** — pick a category, enter building/floor/room, describe it, and attach a
  photo (camera or gallery).
- **Dashboard** — live stats (total / pending / in-progress / resolved), month-over-month trend,
  resolution rate, and an "action required" centre for fixes awaiting your review.
- **Track complaints** — searchable, status-filterable list of your complaints.
- **Complaint details** — full status timeline with actor/time per step, photo lightbox, and
  inline **Accept fix** / **Reopen** actions.

## Architecture

```
lib/
  core/        env (base-URL + photo-URL helpers), constants, theme, formatting, ui helpers
  models/      app_user, complaint, dashboard_stats
  services/    api_client (dio), session_store (shared_preferences), auth + complaint services
  state/       auth_provider, complaints_provider  (provider / ChangeNotifier)
  widgets/     status_badge, complaint_card, dashboard_stat_card, category_avatar,
               gradient_button, accept_reopen_sheets
  screens/     welcome, login, home_shell, dashboard, report, track,
               complaint_details, profile
```

The backend URL is fixed in `lib/core/env.dart` (`Env.baseUrl` →
`https://server.uemcseaiml.org/campusfix/api`); there's no in-app server configuration. The
bearer token and cached user are persisted with `shared_preferences`. Every request carries
`Authorization: Bearer <token>`; a `401` on a protected route logs you out.

## First-time setup (fresh clone)

The app is wired to the **hosted CampusFix backend** at
`https://server.uemcseaiml.org/campusfix/api` — there's no local server to run, no IP to find,
and nothing to configure in-app. Build it onto a device and log in; it reaches the server over
the internet, so the phone doesn't need to be on any particular network.

**Prerequisites:** [Flutter SDK](https://docs.flutter.dev/get-started/install), plus the Android SDK
(for Android) and/or Xcode + CocoaPods (for iOS, macOS only). Verify with `flutter doctor`.

### Run the app

```bash
cd mobile
flutter pub get
flutter devices                 # confirm the phone/emulator is listed
flutter run                     # pick the target if prompted
```

- **Android phone:** enable **Developer options → USB debugging**, connect USB, tap **Allow**.
- **iPhone:** open `ios/Runner.xcworkspace` in Xcode once to set a signing team (a free Apple ID
  works for development), then `flutter run`.

Then log in with your `@uem.edu.in` / `@iem.edu.in` email. Done.

### Pointing at a different backend

The server address is a single constant — `Env.baseUrl` in `lib/core/env.dart`. To target another
deployment (e.g. a local dev backend), edit that constant and rebuild. If you point it at a plain
**HTTP** server, also re-enable cleartext traffic (Android `usesCleartextTraffic`, iOS ATS) — the
hosted backend is HTTPS, so production builds don't need it.

### Troubleshooting

- **Can't log in / requests hang:** confirm the device has internet and that
  `https://server.uemcseaiml.org/campusfix/api/dashboard` responds (a `401` means the API is up).
- **OTP email doesn't arrive:** check spam; the address must be `@uem.edu.in` / `@iem.edu.in`.

## Build an installable APK

```bash
flutter build apk --release     # → build/app/outputs/flutter-apk/app-release.apk
flutter build apk --release --split-per-abi   # smaller, per-architecture (most phones: arm64-v8a)
flutter install                 # build + install to the connected device
flutter build ios               # iOS (requires a full Xcode install + signing)
```

Copy `app-release.apk` to the phone (Drive / email / USB) and tap it — accept **install from unknown
sources**. It points at the hosted backend out of the box, so just open it and log in.

## Tests / analysis

```bash
flutter analyze
flutter test
```
