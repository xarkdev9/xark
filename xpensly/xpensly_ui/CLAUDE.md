# CLAUDE.md — xpensly_ui/

> **Restoration note:** This package was restored from `ui_backup_2026-04-10/flutter/xpensly_ui/` on 2026-04-11. Older references claiming the directory is empty are wrong — it is fully populated.

Flutter widget library for Xpensly. Depends on `xpensly_core` via path dep. No other runtime dependencies beyond Flutter itself.

## Test Command

```bash
cd xpensly/xpensly_ui && flutter test    # 16 tests across 6 files
```

## Package Layout

```
lib/
├── xpensly_ui.dart            # barrel
└── src/
    ├── theme/
    │   ├── xpensly_theme.dart       # XpenslyTheme (InheritedWidget wrapper)
    │   └── xpensly_theme_data.dart  # XpenslyThemeData + presets
    ├── utils/
    │   └── formatters.dart          # currency/date formatting utilities
    └── widgets/
        ├── balance_bar.dart
        ├── debt_card.dart
        ├── expense_entry.dart
        ├── expense_list.dart
        ├── payment_button.dart
        ├── settlement_card.dart
        ├── split_mode_toggle.dart
        ├── trip_summary_widget.dart
        └── xpensly_dashboard.dart
test/
└── widgets/
    ├── balance_bar_test.dart
    ├── debt_card_test.dart
    ├── expense_entry_test.dart
    ├── settlement_card_test.dart
    ├── split_mode_toggle_test.dart
    └── xpensly_dashboard_test.dart
```

## Widget Inventory

| Widget | Purpose |
|--------|---------|
| `BalanceBar` | Visual balance indicator (owed vs. owing) |
| `DebtCard` | Single debt row with payer/payee + amount |
| `ExpenseEntry` | Input form for adding a new expense |
| `ExpenseList` | Scrollable list of expenses with filter support |
| `PaymentButton` | CTA that delegates to `XpenslyPaymentProvider` |
| `SettlementCard` | Settlement action card (mark paid, payment deep-link) |
| `SplitModeToggle` | Segmented control for `SplitMode` enum |
| `TripSummaryWidget` | Compact trip pulse — totals, member balances |
| `XpenslyDashboard` | Full-screen orchestrator; composes the other 8 |

## Theme System

```dart
// Wrap your subtree:
XpenslyTheme(
  data: XpenslyThemeData.hello(),   // dark/cyan — default for hello app
  child: ...,
)

// Other presets:
XpenslyThemeData.material()   // Material 3
XpenslyThemeData.minimal()    // neutral/grayscale
```

Access theme inside a widget: `XpenslyTheme.of(context)`.

## Design Constraints

- No-Bold mandate applies: font-weight max 400 (primary), 300 (secondary).
- Zero-Box: no card borders. Use glass only for functional containers.
- Brand color only in 3-5 specific accent spots; lists and balance rows stay grayscale-clean.
- All colour tokens must use `--hello-*` CSS variables on web; in Flutter use `XpenslyThemeData` tokens, not hardcoded colours.

## Dependency

```yaml
dependencies:
  flutter:
    sdk: flutter
  xpensly_core:
    path: ../xpensly_core
```

Do not add pub.dev dependencies without explicit approval. The widget set intentionally ships with zero third-party Flutter deps.
