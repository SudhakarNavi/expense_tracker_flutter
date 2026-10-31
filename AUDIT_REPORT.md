# Audit Report — Phase 1 Baseline

Project: `expense_tracker` (uploaded as `expense_tracker_flutter_improved.zip`, root folder `expense_tracker_flutter-main/`)
Audit date: 2026-10-21
Status: Sections 1–7 record the **baseline** as found. Section 8 is the **final status** after the work.

The original upload is committed to a *local-only* git repository (commit "Baseline: original uploaded project") so every later change can be diffed. Nothing has been pushed anywhere.

---

## 1. Environment used for the baseline

| Item | Result |
|---|---|
| Flutter SDK | Installed for this audit: Flutter 3.47.7 stable, Dart 3.13.5 (`pubspec.lock` requires Flutter ≥ 3.38.4 / Dart ≥ 3.10.3) |
| Java | OpenJDK 21.0.12 |
| Android SDK | **Not available.** `dl.google.com` (where the Android SDK, build-tools, platforms and NDK are downloaded from) is **blocked by this cloud environment's network policy** (HTTP 403 from the proxy). `maven.google.com`, Maven Central and the Gradle distribution server are reachable. |
| Android emulator / device | **Not available** in this environment (no KVM device, no SDK). |
| `flutter doctor -v` | Flutter ✓, Android toolchain ✗ ("Unable to locate Android SDK"), Chrome ✗, Linux desktop ✗ |

Consequence: analyzer, unit tests and widget tests can run here. **Android debug/release APK builds, APK signature checks, and on-device testing cannot run until `dl.google.com` is allowed** (or the work is done on a machine with the Android SDK).

## 2. Baseline command results (actually executed)

| Command | Result |
|---|---|
| `flutter pub get` | ✅ Succeeded. Updated 3 SDK-pinned transitive packages in `pubspec.lock` (`meta` 1.18→1.19, `test_api` 0.7.11→0.7.12, `vector_math` 2.2→2.4.3) to match the installed SDK, and Flutter auto-added an `analyzer: exclude:` block to `analysis_options.yaml`. These are the only file changes so far. |
| `dart format --output=none --set-exit-if-changed .` | ❌ Exit 1. 3 files are not formatted: `transaction_provider.dart`, `home_screen.dart`, `reports_screen.dart`. |
| `flutter analyze` | ⚠️ 0 errors, 0 warnings, **13 infos** (6× deprecated `withOpacity`, 3× deprecated `DropdownButtonFormField.value`, deprecated `ColorScheme.background`, deprecated `pw.Table.fromTextArray`, 1× `use_build_context_synchronously` in PDF export, 2× const lints). |
| `flutter test` | ❌ **1 of 1 test fails.** `test/widget_test.dart` is the unmodified Flutter "Counter increments" template. It does not open Hive, so the app throws `HiveError: Box not found`. It then looks for a counter that does not exist. **The project has zero meaningful tests.** |
| `flutter build apk` | ⛔ Not run: Android SDK unavailable (see §1). |

## 3. Architecture

```
main.dart ── HiveService.init() (opens untyped Hive box "transactions")
          └─ ChangeNotifierProvider<TransactionProvider>
               └─ MaterialApp (light theme only, Material 3, teal seed)
                    └─ HomeScreen ──push──> AddTransactionScreen
                                  ──push──> ReportsScreen (custom-painted charts, PDF export)
                                  ──push──> CategoriesScreen (read-only totals)
```

* **State management:** `provider` with a single `ChangeNotifier` (`TransactionProvider`) holding an in-memory `List<TransactionModel>`.
* **Storage:** Hive 2.2.3, one untyped box `transactions`. Each record is a `Map` keyed by a UUID: `{id, amount (double), category, note, date (ISO-8601 local, no offset), paymentType, isIncome, bankAccount}`. The model's `fromMap` already reads a legacy `title` field as `note`, which means an older schema existed.
* **Navigation:** imperative `Navigator.push` with `MaterialPageRoute`. No named routes, no bottom navigation.
* **Dependencies (direct):** provider, hive, hive_flutter, uuid, pdf, printing, path_provider. Dev: flutter_lints ^2.0.0 (old major).
* **Platforms in repo:** `android/`, `web/`, `windows/`. There is no `ios/` folder.
* **Android:** AGP 9.0.1, Kotlin 2.3.20, Gradle 9.1.0, Java 17 target. `compileSdk`/`minSdk`/`targetSdk` all delegate to Flutter defaults. `applicationId = com.example.expense_tracker`, label `expense_tracker`, **release build signed with the debug key**, default Flutter launcher icon (byte-identical to the template).
* **Network/permissions:** the release manifest requests **no permissions** and contains no networking code. INTERNET appears only in the debug/profile manifests, as the Flutter template ships it. The `printing` plugin adds a `FileProvider` for sharing. Financial data is local-only.

## 4. Feature inventory (from source, not from the README)

| Area | Status | Notes |
|---|---|---|
| Dashboard summary (balance / income / expense) | Implemented | Figures are computed from the **filtered** list, so the "balance" changes with search/filters. `provider.balance` exists but is unused. |
| Add transaction (income/expense, note, amount, category, payment type, bank account, date) | Implemented, defective | See defects below |
| **Edit transaction** | **Missing** | Not possible at all |
| Delete transaction | Implemented (long-press only) | Has a confirmation dialog; undiscoverable; no undo |
| Search | Implemented | Matches the note text only |
| Filters: category chips, month, start/end date | Implemented | End date treated as inclusive (correct) |
| Categories | Read-only list of 8 hard-coded categories with all-time expense totals | No add/edit/delete; no icons/colors; income and expense categories mixed ("Salary" is offered for expenses) |
| Budgets | **Missing** | |
| Reports: 6-month expense bars, category pie, 7-day trend line | Implemented, defective | Crashes with no data; see defects below |
| PDF export (share / save) | Implemented | "Save to Downloads" actually writes to an app-private folder |
| Settings (currency, theme, etc.) | **Missing** | ₹ and `d/m/yyyy` are hard-coded |
| Dark mode | **Missing** | Light theme only |
| Backup / restore | **Missing** | PDF export is not restorable |
| Bank accounts | Placeholder | Hard-coded fake list: "Axis Bank - 1234", "HDFC - 5678", "SBI - 9012", "ICICI - 3456" |
| Notifications | Not applicable / not present | |

## 5. Defects found (severity-ranked)

Items marked **[Reproduced]** were confirmed by running throwaway tests against an isolated temporary Hive directory. Those tests have since been deleted. The rest come from source review.

### Critical
| ID | Defect | Evidence |
|---|---|---|
| C1 | **Invalid amounts corrupt every total.** `double.tryParse` accepts `NaN`, `Infinity`, `1e400` and negatives. One `NaN` transaction makes balance/income/expense `NaN` permanently, until that record is found and deleted via long-press. A negative "expense" silently *increases* the balance. | [Reproduced] `balance after NaN tx: NaN`; `tryParse("Infinity") = Infinity`, `tryParse("-50") = -50.0` |
| C2 | **One malformed stored record prevents the whole app from loading.** `fromMap` hard-casts every field, so `amount` stored as `int`, or a missing `isIncome`, throws inside `loadTransactions()` while the provider is created. The user then sees a broken home screen and cannot reach any of their data. | [Reproduced] `type 'int' is not a subtype of type 'double'` |
| C3 | **Release build is signed with the debug key.** `buildTypes.release.signingConfig = debug`. It cannot be published, and an update cannot later be signed with a real key without uninstalling (which loses the user's data). | `android/app/build.gradle.kts` |

### High
| ID | Defect | Evidence |
|---|---|---|
| H1 | **Reports screen throws layout assertions when there are no expenses in the last 6 months** (every new user). Bar width = `0/0 = NaN`. The line chart has the same `0/0` and the pie chart uses `3.14` instead of π. | [Reproduced] 5× `BoxConstraints(NaN<=w<=NaN)` assertions |
| H2 | **Home screen overflows on small screens / large text / open keyboard.** The fixed header and filter card sit in a non-scrolling `Column` above the list. | [Reproduced] 320×568 at 1.3× text: `RenderFlex overflowed by 827 pixels` |
| H3 | **No way to edit a transaction** (core workflow). | Source |
| H4 | **Save is not protected against double taps.** It writes and calls `Navigator.pop` synchronously each time, so a second tap that lands before the route is gone can add a duplicate and pop the Home route. | Source. One automated double-tap attempt did *not* reproduce a duplicate (1 record saved), so this is unconfirmed and will be guarded anyway. |
| H5 | **Storage writes are fire-and-forget.** `box.put` / `box.delete` are not awaited. The UI shows success even if the write fails, and errors are unhandled. `Hive.openBox` failure in `main()` gives a blank screen with no message. | Source |
| H6 | **Amount keyboard has no decimal key on many Android keyboards** (`TextInputType.number` without `decimal: true`). | Source |
| H7 | **Application ID `com.example.expense_tracker`** is rejected by Google Play, and the app label is `expense_tracker`. | Manifest / Gradle |
| H8 | **No real automated tests**; the only test fails. | `flutter test` |

### Medium
| ID | Defect |
|---|---|
| M1 | Money is stored and summed as `double`: 0.1+0.1+0.1 = `0.30000000000000004` [Reproduced]. Display rounds it today, but totals drift and comparisons (budgets) become unreliable. |
| M2 | Transaction amounts on the list are shown unformatted (`-₹12.5`, `-₹1e+21`); no thousands separators. |
| M3 | The dashboard "balance" means different things depending on filters; it is not labeled as a filtered figure. |
| M4 | The add-form date picker only allows ±365 days, so older history cannot be entered. |
| M5 | Note is mandatory, but the field is labeled "Notes" and categories already describe the item. |
| M6 | Hard-coded fake bank-account names shown to real users. |
| M7 | "Save to Downloads" saves to the app-specific external folder (deleted on uninstall) and tells the user it saved to Downloads. On failure it shows the raw exception text. |
| M8 | PDF uses the default Helvetica font. Non-Latin notes (Hindi, Tamil, etc.) will not render. |
| M9 | `BuildContext` used across an async gap in PDF export (analyzer info). |
| M10 | Bar chart width uses `screenWidth*0.5` inside a narrower `Expanded`, so the largest bars are clipped and not proportional. Month labels read "5/2026". |
| M11 | Privacy: Android `allowBackup` defaults to true, so the unencrypted Hive file is included in Google cloud auto-backup. This may be desired, but it must be disclosed or decided. |
| M12 | Search only matches notes, not category / payment type / amount. |
| M13 | Delete is long-press only: undiscoverable, with no undo. |

### Low
| ID | Defect |
|---|---|
| L1 | 13 analyzer infos (deprecations, const). 3 files unformatted. |
| L2 | No dark theme; hard-coded colors (`Colors.black54`, `grey.shade200`) would break it. |
| L3 | Default Flutter launcher icon and white launch screen. |
| L4 | `CustomPainter.shouldRepaint` always returns false. |
| L5 | `flutter_lints ^2.0.0` is several majors behind (lint coverage only; not a runtime risk). |
| L6 | `gradle.properties` requests an 8 GB heap, which can fail on low-RAM build machines. |
| L7 | Unused `web/` and `windows/` targets; the README is minimal. |

## 6. Security & privacy snapshot
* Data stays on device: no network code, no analytics, no ads, no INTERNET permission in release.
* No secrets, API keys or keystores in the repo.
* No logging of financial data (no `print`/`debugPrint` calls).
* Hive data is unencrypted in app-private storage and eligible for Android auto-backup (M11).
* PDF share hands data to whatever app the user picks (user-initiated, expected).

## 7. Release blockers (current)
1. Android SDK cannot be downloaded in this environment (`dl.google.com` blocked), so no APK can be built or verified here yet.
2. Debug-key signing (C3) and `com.example` application ID (H7) both need owner decisions.
3. C1, C2, H1–H6 must be fixed and covered by tests.

---

## 8. Final status (after implementation)

### Decisions made by the owner
| Decision | Choice |
|---|---|
| Application ID | Change to `com.navisudhakar.expensetracker` (app not yet installed by users) |
| Money storage | Integer minor units, non-destructive (legacy records read as-is, never rewritten on load) |
| New features | Monthly budgets, category management, dark mode + settings, backup & restore |
| Hard-coded bank accounts | Replace with generic accounts; keep existing values on old records |

### Feature status
| Area | Status |
|---|---|
| Dashboard | Implemented and tested (balance, month income/expense/net, savings rate, budgets, top categories, recent) |
| Add / edit / delete transactions | Implemented and tested (validation, double-tap guard, confirmation, undo) |
| Search & filters | Implemented and tested (text, type, period, custom range, category) |
| Categories | Implemented and tested (add/rename/recolor/icon/delete with safe reassignment) |
| Budgets | Implemented and tested (overall + per category; under/near/reached/exceeded) |
| Reports | Implemented and tested (month/year, category donut, trend, daily); PDF export: generation tested, share/save dialogs need a device |
| Settings | Implemented and tested (theme, currency, categories, backup, restore, erase) |
| Backup & restore | Encode/decode/merge tested; file dialogs need a device |
| Persistence | Verified with real Hive files, including the original v1 schema |
| Notifications | Not applicable (not part of the app) |

### Files changed
* **Rewritten/added (lib):** `main.dart`, `app.dart`, `models/*`, `providers/*` (transaction, category, budget, settings), `services/*` (finance_calculator, backup_service, pdf_report_service, category_actions, hive_service, key_value_store), `screens/*` (shell, dashboard, transactions, transaction_form, reports, budgets, categories, settings), `widgets/*`, `theme/app_theme.dart`, `utils/*` (money, date_utils, app_constants).
* **Removed:** `screens/home_screen.dart`, `screens/add_transaction_screen.dart` (replaced by the screens above), `test/widget_test.dart` (counter template).
* **Android:** `app/build.gradle.kts` (ID, signing), `AndroidManifest.xml` (label), MainActivity moved to the new package, launcher icons (adaptive + legacy), launch screen and colors, `gradle.properties` (heap).
* **Tests:** `test/unit/*` (7 files), `test/widget/*` (2 files + helpers), `integration_test/app_test.dart`.
* **Config/docs:** `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml` (auto-excludes), README and the five reports.

### Known limitations and remaining issues
1. **No APK has been built or run.** The Android SDK cannot be downloaded in this environment. Everything Android-specific (Gradle signing logic, new app ID, resources, plugins on AGP 9 / Gradle 9.1, file dialogs, sharing) is **unverified by a build or a device**.
2. PDF export renders non-Latin text (Hindi, Tamil, …) as boxes. A proper fix means bundling Noto fonts (several MB per script); not done without approval.
3. Hive data is not encrypted at rest. It relies on Android's app sandbox. Android device backup may include it if the user has backups enabled (disclosed in-app).
4. Currency setting changes the symbol only; there is no multi-currency or conversion.
5. Budgets recur monthly with the same limit; there are no per-month overrides or rollover.
6. `flutter_lints` is still ^2.0.0 (old major); upgrading would add lint work but no runtime change.
7. `web/` and `windows/` folders were left as-is and not tested; the README targets Android.
8. Search and filters are linear scans. That's fine for thousands of records but not profiled on a device.
9. Dates are stored as local time without a zone offset (as in v1). If a user changes time zone, existing timestamps keep their wall-clock value.

### Go / no-go
**NO-GO for public release yet.** The code side meets the acceptance criteria that can be checked here:
* ✅ No known unresolved critical or high defects in the code
* ✅ All implemented features covered by automated tests; financial logic verified by unit tests
* ✅ Persistence verified with real storage files
* ✅ `flutter analyze` clean, formatter clean, 98/98 tests pass
* ✅ Security and privacy reviewed and documented; no permissions, network, analytics or secrets

These release criteria are **not met** and block a release:
* ⛔ Release APK built successfully
* ⛔ Release signing verified (also needs the owner's keystore)
* ⛔ Installation and core workflows verified on a device

**Next actions:** (1) allow `dl.google.com` in this environment's network settings, or build on a machine with the Android SDK; (2) create the upload keystore and `android/key.properties`; (3) run `flutter build apk --release`, `apksigner verify`, the integration test and the manual checklist in `TEST_PLAN.md`; (4) fix anything they reveal, then re-assess.

---

## 9. Follow-up audit — 2026-10-31

| Check | Result |
|---|---|
| Environment | Flutter 3.44.0 stable, Dart 3.12.0, Android SDK 36.1.0, Android licenses accepted |
| `dart format --output=none --set-exit-if-changed .` | Passed: 42 files checked, 0 changes required |
| `flutter analyze` | Passed: no issues found |
| `flutter test` | Passed: 98/98 tests |
| Chrome debug run | Passed: application started and all four Hive stores opened without a runtime exception |
| Android integration test | Not available: no emulator or connected Android device |

### Issue found and fixed

| ID | Issue | Fix and verification |
|---|---|---|
| L7 | `integration_test/app_test.dart` referenced Flutter test helpers (`setUp`, `testWidgets`, `expect`, `find`) without importing `package:flutter_test/flutter_test.dart`, causing 18 analyzer errors. | Restored the missing import. Re-running `flutter analyze` reported no issues. |

### Remaining validation limitations

* Android integration and device-only file-picker flows cannot run until an Android device or emulator is available.
* Chrome debug startup verified the application boot path, but the README correctly defines Android as the supported production target.
