# BimaFleet

Offline-first vehicle compliance, renewal and preventive service ledger built with Flutter (Dart) for Android and Web.

## Quick start

```bash
flutter create --platforms=web,android --project-name bima_fleet .
flutter pub get
flutter run
```

## Web / Vercel

```bash
flutter build web --release --base-href /
```

Deploy the repository to Vercel. The included `vercel.json` serves `build/web` with SPA fallback. Vercel build settings use `bash tool/vercel-build.sh` and output directory `build/web`.

## Android APK

```bash
flutter build apk --release
```

The GitHub Actions workflow builds and publishes `app-release.apk` as the `BimaFleet-latest` GitHub Release asset. The in-app APK Center links to that asset.

## Offline storage

Vehicle and service data are persisted locally with Hive. Data stays on the device/browser profile; this starter does not silently upload fleet or driver information to a server. Export a JSON backup from Settings regularly.

## Roles

Fleet Manager can manage vehicle records, thresholds, budgets and exports. Driver / Yard Clerk can add odometer readings and service entries, and view compliance information.

## Notes

Dates are evaluated using the device's local calendar. Set realistic renewal and service intervals for your jurisdiction and fleet policy; this tool is a ledger/reminder system, not a government verification service.
