# Expense Tracker

An offline personal-finance app for Android, built with Flutter. No account, no internet permission, no analytics: every record stays on the device.

## Features
* **Overview**: total balance, the selected month's income, expenses and net savings, budget status, top spending categories, recent transactions.
* **Transactions**: add, edit (tap) and delete (swipe or the Delete button, with Undo). Search across note, category, payment method, account and amount. Filter by type, period and category. List grouped by day.
* **Reports**: month or year view, spending by category, income vs expenses trend, daily spending, PDF export (share or save).
* **Budgets**: an overall monthly limit plus per-category limits; under / near (80%) / reached / exceeded states.
* **Categories**: add, rename, recolor, change icon, delete. Transactions move to "Other" on delete, and renames carry transactions and budgets along.
* **Settings**: light/dark/system theme; currency symbol (INR, USD, EUR, GBP, AED, SGD, AUD, CAD; display only, no conversion); JSON backup and merge-only restore; erase all data (requires typing `DELETE`).

## Requirements
* Flutter **3.38.4 or newer** (developed and tested with 3.47.7 stable, Dart 3.13.5)
* Android SDK with platform 36 (installed by Android Studio), JDK 17+
* Android 7.0 (API 24) or newer on the device

## Run
```bash
flutter pub get
flutter run
```

## Test
```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test                                        # 98 unit + widget tests, no device needed
flutter test integration_test/app_test.dart -d <device-id>   # on a phone/emulator
```
Tests never touch real data: they use in-memory stores or a temporary Hive directory.

## Release signing
Release builds are **not** signed with the debug key. A release build stops with instructions until signing is configured.

1. Create an upload keystore once, and keep it and its passwords safe and backed up. Without them you can never publish an update.
   ```bash
   keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Create `android/key.properties` (already gitignored; **never commit it**):
   ```properties
   storePassword=<password>
   keyPassword=<password>
   keyAlias=upload
   storeFile=/absolute/path/to/upload-keystore.jks
   ```
3. Build:
   ```bash
   flutter build apk --release          # universal APK for direct installs
   flutter build appbundle              # for Google Play
   ```
   Output: `build/app/outputs/flutter-apk/app-release.apk`
4. Verify the signature:
   ```bash
   apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
   ```

For a local test build only, `ALLOW_DEBUG_SIGNING=true flutter build apk --release` signs with the debug key. Never distribute that APK.

## Project structure
```
lib/
  main.dart                 storage bootstrap + startup error screen
  app.dart                  providers, theme, first load
  models/                   transaction, category, budget (tolerant readers)
  providers/                state + persistence (all writes awaited)
  services/
    finance_calculator.dart the single source of financial figures
    backup_service.dart     JSON backup / merge-only restore
    pdf_report_service.dart PDF export
    hive_service.dart       Hive boxes behind a KeyValueStore interface
  screens/                  overview, transactions, form, reports, budgets, categories, settings
  widgets/                  shared UI (amounts, charts, tiles, dialogs)
  utils/                    money (integer minor units), dates, constants
test/unit, test/widget, integration_test/
```

## Data and privacy
| | |
|---|---|
| Stored | Transactions, categories, budgets, theme and currency, in Hive boxes in the app's private storage on the device. Not encrypted at rest; Android sandboxing protects it from other apps. |
| Transmitted | Nothing automatically. The app has no INTERNET permission. Data leaves the device only when the user exports a PDF or backup and chooses where to send or save it. |
| Device backup | Android's own device backup may include app data if the user has it enabled. |
| Deleted | Single records on delete (with Undo); everything via Settings → Erase; all app data on uninstall. Exported files are the user's to manage. |

## Data compatibility
Records created by earlier versions (double `amount`, optional `title`) are read as-is and are **not rewritten** on load. Editing a record adds an exact `amountMinor` field and keeps `amount` for older builds. Records that cannot be read safely are left untouched and reported in Settings.

## Reports in this repository
`AUDIT_REPORT.md` · `BUGS_AND_FIXES.md` · `TEST_PLAN.md` · `TEST_RESULTS.md` · `RELEASE_CHECKLIST.md`
