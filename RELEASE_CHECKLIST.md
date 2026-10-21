# Release Checklist

Legend: ✅ done and verified · ⚠️ done, not verifiable here · ⛔ blocked · ☐ owner action

## Configuration
| Item | Status | Detail |
|---|---|---|
| Application ID | ⚠️ | `com.navisudhakar.expensetracker` (namespace and Kotlin package match). Approved by the owner, since no users had the old ID. |
| App name | ⚠️ | "Expense Tracker" (`android:label`) |
| Version | ✅ | `1.0.0+1` (pubspec). Bump `+N` for every upload. A unit test keeps the in-app version in sync. |
| SDK levels | ✅ | Flutter-managed: minSdk 24 (Android 7.0), target/compile 36, NDK 28.2.13676358. Not changed. |
| Permissions (release) | ✅ | **None requested by the app.** Plugins add only a `FileProvider` (printing) and package-visibility `<queries>`. INTERNET exists only in the debug/profile manifests (Flutter tooling). |
| Launcher icon | ⚠️ | Adaptive icon + monochrome layer (Android 13 themed icons) + legacy PNGs for API 24–25 |
| Launch screen | ⚠️ | Brand background with icon; dark-mode variant |
| Cleartext traffic | ✅ | No network code at all |
| Analytics / ads / tracking | ✅ | None present, none added |
| Secrets in repo | ✅ | None. `key.properties`, `*.jks` and `*.keystore` are gitignored (`android/.gitignore`). |

## Release signing
| Item | Status |
|---|---|
| Debug-key signing removed from release | ⚠️ (Gradle not runnable here) |
| `key.properties` loading | ⚠️ |
| Build refuses to sign a release with the debug key unless `ALLOW_DEBUG_SIGNING=true` | ⚠️ |
| ☐ Create the upload keystore and `android/key.properties` (README → *Release signing*) | Owner |
| ☐ Back up the keystore and passwords somewhere safe and offline. **Losing them means you can never update the app.** | Owner |

## Build and verification
| Step | Status | Notes |
|---|---|---|
| `flutter analyze` | ✅ No issues | |
| `flutter test` | ✅ 98/98 | |
| `flutter build apk --release` | ⛔ | "No Android SDK found". The environment blocks `dl.google.com`. |
| APK path and size | ⛔ | Expected at `build/app/outputs/flutter-apk/app-release.apk` |
| `apksigner verify --print-certs` | ⛔ | |
| Install and launch on device/emulator | ⛔ | |
| `integration_test/app_test.dart` on device | ⛔ | |
| Manual checklist in `TEST_PLAN.md` | ⛔ | |

### How to unblock (owner)
Either:
1. **Allow `dl.google.com`** in this cloud environment's network settings (environment menu → Edit → Network access → add the domain, keep "Allow package managers" ticked; docs: https://code.claude.com/docs/en/cloud-environments#network-access) and ask me to continue; or
2. Build on your own computer with Android Studio / Android SDK installed:
   ```bash
   flutter pub get
   flutter test
   flutter build apk --release        # after creating android/key.properties
   apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
   flutter install                    # or: adb install -r build/app/outputs/flutter-apk/app-release.apk
   flutter test integration_test/app_test.dart -d <device-id>
   ```

### APK vs App Bundle
* **Universal APK** (`flutter build apk --release`): one file for sideloading; contains arm64-v8a, armeabi-v7a and x86_64 native code, so it is the largest option (size not measured; no build possible here).
* **Split APKs** (`--split-per-abi`): one smaller APK per CPU architecture, but users must get the right one for their phone.
* **App Bundle** (`flutter build appbundle`): required by Google Play; Play delivers per-device APKs.
Recommendation: a universal APK for direct distribution, an App Bundle for Play.

## Final smoke test (run on the release build)
☐ Install fresh → icon/name correct → launch → empty state
☐ Add income, add expense → totals correct
☐ Edit → totals update; delete → confirm → undo
☐ Force-stop → relaunch → data intact
☐ Reports month/year; PDF share and save
☐ Budget exceeded/reached states
☐ Dark mode; currency switch
☐ Backup → uninstall → reinstall → restore → totals match
☐ Airplane mode: all features work
☐ Back button: form → tab → Overview → exit
