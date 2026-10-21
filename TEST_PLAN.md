# Test Plan

## Principles
* Automated tests never touch real user data. Unit and widget tests use `MemoryStore`. Hive persistence tests and the device integration test use a fresh temporary directory, which is deleted afterwards.
* Financial logic lives in one place (`lib/services/finance_calculator.dart`), and every screen calls it. Tests cover the calculator directly, and the end-to-end flow checks that Dashboard and Reports agree.
* Money is integer minor units. Tests assert exact integers, never approximate doubles.

## Financial definitions under test
| Figure | Definition |
|---|---|
| Income / Expenses | Sum of amounts of that type in scope |
| Net savings (period) | Income − Expenses in the period |
| Total balance | All-time income − all-time expenses (the app has no opening balance) |
| Savings rate | Net ÷ Income; hidden when income is 0 |
| Month / year | Half-open local ranges `[1st 00:00, next 1st 00:00)` |
| Budget state | under < 80% ≤ near < 100% = reached < exceeded |

## Automated suites (`flutter test`)
| Suite | File | Covers |
|---|---|---|
| Money | `test/unit/money_test.dart` | Parsing (grouping, decimal comma, zero, negative, NaN, Infinity, exponent, > 2 decimals, max value), Indian/Western formatting, compact form, legacy-double conversion, round trips, no drift |
| Dates | `test/unit/date_utils_test.dart` | Month/year rollover, leap years (2000, 2024, 2025, 2100), inclusive day ranges, labels across month boundaries |
| Model | `test/unit/transaction_model_test.dart` | v1 records (double/int amount, `title` field, missing id), rejection of unsafe records, round trip keeping unknown fields, `amountMinor` precedence |
| Calculator | `test/unit/finance_calculator_test.dart` | Empty data, totals, negative balance, 1000 × 0.10, very large sums, month-end/year-end/leap-day attribution, monthly vs yearly consistency, category totals = expense total, budget under / near / reached / exceeded by 1 paisa / scoped by category and month |
| Providers | `test/unit/providers_test.dart` | Add/edit/delete in sync with storage, type change, duplicate save, **write failure leaves state intact**, unreadable records preserved, reload (restart), ordering, search/filters, category seeding/validation/protection, rename and delete propagation to transactions and budgets, budget persistence, settings defaults/persistence |
| Backup & PDF | `test/unit/backup_and_pdf_test.dart` | Export → import into an empty device, merge without overwriting or deleting, re-import is a no-op, missing categories created, rejection of non-backups and newer versions, partial bad rows, valid PDF (with data, empty, non-Latin text), app version matches pubspec |
| Persistence | `test/unit/hive_persistence_test.dart` | **Real Hive files**: all four boxes survive close/reopen; **a box in the exact v1 schema** loads correctly, isn't rewritten on load, and keeps the legacy field when edited |
| End-to-end flow | `test/widget/app_flow_test.dart` | Launch → add income → add expense → verify totals → edit → verify → delete with confirmation → undo → **restart** → search/filters → budget exceeded → Reports equal Dashboard; validation messages; triple-tap Save; storage failure; discard-changes prompt; system back |
| Screens | `test/widget/screens_test.dart` | Empty states on all tabs; reports period/year navigation; **9-way overflow matrix** (320×568, 360×640, 800×1280 × text 1.0/1.5/2.0) across all tabs, form and settings; dark mode persistence; currency switch; unreadable-record notice; erase requires `DELETE`; category add/duplicate/rename/delete |

## Device tests (require an emulator or phone)
* `integration_test/app_test.dart`: add income + expense, verify, simulated restart, verify. Run with `flutter test integration_test/app_test.dart -d <device>`.

## Manual checklist (device required, not yet executed)
1. Install the release APK; launch; check the icon, name and launch screen in light and dark mode.
2. Add, edit and delete transactions; force-stop the app; relaunch; data is present.
3. Background the app mid-entry, then resume: the form keeps its content.
4. Rotate the screen and use split-screen; layouts adapt.
5. Android back: form → list → Overview → exit.
6. Export a backup to Downloads; uninstall; reinstall; restore; totals match.
7. Export PDF → Share (e.g. to Files/Drive) and → Save; open the PDF.
8. TalkBack: walk the Overview, Transactions, form, and Budgets screens.
9. Font size at maximum (Settings → Display) on a small phone.
10. Airplane mode: everything works (the app has no network use).
11. Cancel the file picker during backup/restore/PDF save: no error, no change.
