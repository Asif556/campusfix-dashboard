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
               complaint_details, profile, settings
```

The bearer token, cached user, and server URL are persisted with `shared_preferences`. Every
request carries `Authorization: Bearer <token>`; a `401` on a protected route logs you out.

## Running it

1. **Start the backend** (from the repo root):

   ```bash
   cd ../backend
   source venv/bin/activate
   python app.py            # serves http://127.0.0.1:5000
   ```

2. **Run the app:**

   ```bash
   cd mobile
   flutter pub get
   flutter run              # pick your device / emulator / simulator
   ```

### Pointing the app at your backend

The app defaults the server address per platform:

| Target                | Default base URL                              |
| --------------------- | --------------------------------------------- |
| Android emulator      | `http://10.0.2.2:5000/campusfix/api`          |
| iOS simulator / other | `http://127.0.0.1:5000/campusfix/api`         |

`10.0.2.2` is the Android emulator's alias for your host machine. On a **physical phone**, use your
computer's LAN IP (e.g. `http://192.168.1.5:5000/campusfix/api`) and make sure the phone is on the
same network. You can change and **Test** the address any time from **Welcome → ⚙︎** or
**Profile → Server Settings** — no rebuild needed.

Cleartext HTTP is enabled for development (Android `usesCleartextTraffic`, iOS ATS arbitrary loads)
because the backend runs over plain HTTP locally. For a production HTTPS backend, tighten both.

## Build

```bash
flutter build apk           # Android (release)
flutter build ios           # iOS (requires a full Xcode install + signing)
```

## Tests / analysis

```bash
flutter analyze
flutter test
```
