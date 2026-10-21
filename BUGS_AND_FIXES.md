# Bugs and Fixes

IDs match `AUDIT_REPORT.md`. "Verified by" names the automated test that now guards the fix. Every listed test was run and passed (see `TEST_RESULTS.md`).

## Baseline defects

| ID | Severity | Defect | Fix | Verified by |
|---|---|---|---|---|
| C1 | Critical | `NaN`, `Infinity`, negative and exponent amounts were accepted, and one `NaN` made every total `NaN` | New `Money.parse` accepts only positive decimals with ≤ 2 places and ≤ 999,999,999,999.99. The amount field also blocks letters and signs as you type. | `money_test` (parse group), `app_flow_test` "amount validation blocks bad input" |
| C2 | Critical | One malformed stored record (e.g. `int` amount, missing `isIncome`) crashed loading and hid all data | `TransactionModel.tryFromMap` reads legacy shapes (int/double/string amounts, `title`→note, missing id → storage key). Records it can't read safely are skipped, **left untouched in storage**, and counted in a Settings warning. | `transaction_model_test`, `providers_test` "unreadable stored records…", `screens_test` "unreadable stored records are reported" |
| C3 | Critical | Release build signed with the debug key | Release signing now comes from `android/key.properties` (gitignored). A release build without it **fails with instructions** instead of silently using the debug key; the `ALLOW_DEBUG_SIGNING=true` env var allows a local test build only. | Not verifiable here (no Android SDK); see `RELEASE_CHECKLIST.md` |
| H1 | High | Reports screen threw `NaN` layout assertions when there were no recent expenses | Charts rewritten with zero-guards on every division; empty states added | `screens_test` "every tab renders with no data" |
| H2 | High | Home screen overflowed by 827 px on small screens / large text | Redesigned as scrollable tabs; all rows made flexible; amounts scale down rather than truncate | `screens_test` 9 × "no overflow at {320×568, 360×640, 800×1280} × text {1.0, 1.5, 2.0}" |
| H3 | High | No way to edit a transaction | Tap any transaction to edit; the same form handles add and edit | `app_flow_test` main flow (step 4) |
| H4 | High | Save was not guarded against repeated taps | `_saving` guard, disabled button with spinner, await-then-pop | `app_flow_test` "rapid double tap on Save stores exactly one transaction" |
| H5 | High | Storage writes were fire-and-forget; a failed write still showed success; startup failure gave a blank screen | All writes awaited; memory updated only after success; errors shown and the form stays open; startup error screen with Retry (deletes nothing) | `providers_test` "a failed write leaves memory unchanged", `app_flow_test` "a storage failure keeps the form open" |
| H6 | High | Number keyboard had no decimal key on many devices | `TextInputType.numberWithOptions(decimal: true)`; decimal comma also accepted | `money_test` decimal-comma test |
| H7 | High | `com.example.expense_tracker` ID, label `expense_tracker` | ID and namespace `com.navisudhakar.expensetracker` (owner-approved), label "Expense Tracker", MainActivity package moved | Source review; build not possible here |
| H8 | High | Only test was the failing counter template | 98 automated tests | `TEST_RESULTS.md` |
| M1 | Medium | Floating-point money (`0.1×3 = 0.30000000000000004`) | Integer minor units (`amountMinor`) everywhere. Non-destructive: legacy records are rounded in memory only, and edited records keep the old `amount` field for older builds. | `money_test` "integer sums do not drift", `hive_persistence_test` v1 schema test |
| M2 | Medium | Unformatted amounts (`-₹1e+21`) | `Money.format` with Indian/Western grouping, tabular figures | `money_test` format group |
| M3 | Medium | Dashboard "balance" changed with filters | One definition: balance = all-time income − expenses. Period figures are labelled as such. Every screen uses `FinanceCalculator`. | `finance_calculator_test`, `app_flow_test` step 9 (Reports = Dashboard) |
| M4 | Medium | Date picker limited to ±365 days | 1 Jan 2000 to one year ahead, with a warning for future dates | Source review |
| M5 | Medium | Note was mandatory | Note optional (max 120 chars); the category name is shown when there's no note | `app_flow_test` double-tap test (saves without note) |
| M6 | Medium | Fake bank accounts ("Axis Bank - 1234" …) | Generic accounts (owner-approved); old values on existing records are kept and shown | `hive_persistence_test` ("old values kept") |
| M7 | Medium | "Save to Downloads" wrote to an app-private folder; raw exception text shown | System save dialog (`file_picker`), so the user picks the real location. Friendly error messages. | Not testable without a device |
| M8 | Medium | PDF can't render non-Latin text | **Not fully fixed**: generation no longer risks a crash and amounts use currency codes (INR). Non-Latin characters still render as boxes. See known limitations. | `backup_and_pdf_test` "non-Latin notes do not crash" |
| M9 | Medium | `BuildContext` used across async gap in export | Rewritten with `mounted` checks | `flutter analyze`: 0 issues |
| M10 | Medium | Bar chart clipped and not proportional; labels like "5/2026" | New `BarChart` scaled to its own width, month-name labels, accessible summary | `screens_test` reports tests |
| M11 | Medium | Android auto-backup includes unencrypted data | **Kept as-is, disclosed** in the in-app privacy text and docs (turning it off could lose data for users who rely on it) | Documented |
| M12 | Medium | Search matched notes only | Searches note, category, payment type, account and amount | `providers_test` filter test |
| M13 | Medium | Delete was long-press only, with no undo | Swipe left or the Delete button in edit; confirmation plus Undo | `app_flow_test` step 5 |
| L1 | Low | 13 analyzer infos, 3 unformatted files | 0 analyzer issues, formatter clean | `TEST_RESULTS.md` |
| L2 | Low | No dark theme | Light/Dark/System, persisted | `screens_test` "dark theme setting applies and persists" |
| L3 | Low | Default Flutter icon, white launch screen | Custom adaptive icon (with monochrome layer), branded launch screen with a dark variant | Visual check of generated icon |
| L4 | Low | `shouldRepaint` always false | Painters compare their inputs | Source review |
| L6 | Low | 8 GB Gradle heap | 4 GB | — |

## Defects found and fixed *during* this work (caught by the new tests)

| Defect | Found by | Fix |
|---|---|---|
| Form asked "Discard changes?" when nothing had been typed: controllers also notify on focus/selection | Overflow test (back from an untouched form) | Dirty state compares actual text with the initial values |
| Form used a lazy `ListView`, so fields below the fold weren't built and **`Form.validate()` could skip them** | Flow test (note field not found) | Form body is a non-lazy `SingleChildScrollView` |
| Erase-data dialog disposed its `TextEditingController` while the closing animation still used it | Erase-data test | Dialog is its own `StatefulWidget` that owns the controller |
| Budget editor crashed while closing: options were recomputed and the just-saved category disappeared from the dropdown | Flow test (budget step) | Options captured once when the sheet opens |
| Hidden "Add transaction" FAB on Budgets/Reports was still announced to screen readers | Flow test (two FABs found) | FAB removed rather than scaled to zero |
| "Clear filters" chip was off-screen at the end of a horizontal list | Flow test | Moved to the front when filters are active |
| Seven rows overflowed at large text or narrow widths (budget rows, top-spending, legends, dropdowns, card headers) | Overflow matrix | `Wrap`/`Flexible`, `isExpanded` dropdowns, amounts scale down instead of truncating |
| Amount `Semantics` merged into parents, so TalkBack read run-on text | Flow test (semantic label lookups) | `container: true` on amount semantics nodes |

## Dependency changes

| Change | Reason |
|---|---|
| **Added `file_picker: ^13.1.0`** | Real "Save as…" / "Open" dialogs for backup, restore and PDF save. Uses the Android Storage Access Framework, so **no storage permissions are needed**. |
| Added `integration_test` (Flutter SDK, dev only) | On-device test in `integration_test/app_test.dart` |
| `environment.sdk` `>=3.0.0` → `>=3.10.0` | `pubspec.lock` already required Dart ≥ 3.10.3; the code uses Dart 3.10 language features |
| `pubspec.lock`: `meta`, `test_api`, `vector_math` | Pinned by the Flutter SDK (automatic on `pub get`) |
| No dependency upgraded otherwise | `flutter_lints ^2.0.0` left as-is to avoid churn |
