# Test Results

Run date: 2026-10-21, in a Linux cloud container.
Toolchain: Flutter 3.47.7 stable (revision abaf9c5237), Dart 3.13.5, OpenJDK 21.0.12.
Every result below is from a command that was actually run. Nothing here is estimated.

## Static checks
| Command | Baseline (original upload) | Final |
|---|---|---|
| `flutter pub get` | ✅ | ✅ |
| `dart format --output=none --set-exit-if-changed .` | ❌ exit 1 (3 files) | ✅ exit 0 |
| `flutter analyze` | 13 infos | ✅ **No issues found** |
| `osv-scanner` (offline OSV Pub database, 89 packages in `pubspec.lock`) | not run | ✅ No known vulnerabilities. Note: OSV's Pub coverage is limited; this isn't a full security audit. |

## Automated tests: `flutter test`
**Final: 98 passed, 0 failed, 0 skipped** (exit code 0).

| File | Tests | Result |
|---|---|---|
| test/unit/money_test.dart | 14 | ✅ |
| test/unit/date_utils_test.dart | 5 | ✅ |
| test/unit/transaction_model_test.dart | 8 | ✅ |
| test/unit/finance_calculator_test.dart | 19 | ✅ |
| test/unit/providers_test.dart | 18 | ✅ |
| test/unit/backup_and_pdf_test.dart | 10 | ✅ |
| test/unit/hive_persistence_test.dart | 2 | ✅ (real Hive files in a temp dir) |
| test/widget/app_flow_test.dart | 6 | ✅ |
| test/widget/screens_test.dart | 16 | ✅ |

Baseline for comparison: 1 test (Flutter counter template), **failed** with `HiveError: Box not found`.

While the new tests were being brought up, they exposed eight more defects in the new code, listed in `BUGS_AND_FIXES.md`. All were fixed and the full suite re-run.

### Baseline reproductions (before any change)
Run against the untouched original code with a temporary Hive directory; the throwaway test files were deleted afterwards:
* Reports with no data: 5 × `BoxConstraints(NaN<=w<=NaN)` assertions.
* Home at 320×568, text 1.3×: `RenderFlex overflowed by 827 pixels`.
* `double.tryParse` accepted `NaN`, `Infinity`, `-50`; one NaN transaction made the balance `NaN`.
* A record with an `int` amount: `type 'int' is not a subtype of type 'double'` while loading all data.
* `0.1 × 3` income total = `0.30000000000000004`.

## Not executed (and why)
| Item | Status | Reason |
|---|---|---|
| `flutter build apk --release` | ❌ **Ran and failed:** `No Android SDK found` | This environment's network policy blocks `dl.google.com`, the only source of the Android SDK, build-tools, platforms and NDK |
| `flutter build apk --debug` | Not run | Same blocker |
| APK signature check (`apksigner verify`) | Not run | No APK; no SDK build-tools |
| Gradle configuration (new signing logic, ID change, resources) | **Unverified by a build** | AGP cannot configure without the SDK. The XML resources were checked for well-formedness only. |
| `integration_test/app_test.dart` | Not run | Needs an emulator or device; none available (no SDK, no KVM) |
| Manual device checklist (`TEST_PLAN.md`) | Not run | No device |
| `file_picker` / `printing` share and save dialogs | Not run | Platform channels only work on a device |
| TalkBack, real keyboard, rotation, backgrounding | Not run | No device. Widget tests cover semantics labels, text scaling and layout sizes only. |
| `flutter doctor -v` | Ran: Flutter ✓; Android toolchain ✗ (no SDK); Chrome ✗; Linux desktop ✗ | Informational |
