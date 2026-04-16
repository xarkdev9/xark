# CLAUDE.md — xpensly_core/

Pure Dart expense-splitting engine. Zero Flutter dependency. SDK ≥ 3.0.0. Only runtime dep: `collection: ^1.17.0`.

## Test Commands

```bash
cd xpensly/xpensly_core && dart test          # 69 tests across 12 files
cd xpensly/xpensly_core && dart analyze       # static analysis, target: 0 errors
```

## Package Layout

```
lib/
├── xpensly_core.dart          # barrel — all public exports
└── src/
    ├── models/                # Freezed-style value types
    │   ├── member.dart
    │   ├── expense.dart
    │   ├── split_mode.dart    # enum SplitMode { equal, exact, percentage, shares }
    │   ├── split_result.dart
    │   ├── debt_delta.dart
    │   ├── settlement.dart
    │   ├── trip.dart
    │   ├── refund.dart
    │   ├── settlement_record.dart
    │   ├── config.dart
    │   ├── trip_summary.dart
    │   └── expense_filter.dart
    ├── engine/                # Pure calculation modules
    │   ├── split_calculator.dart
    │   ├── settlement_engine.dart
    │   ├── debt_simplifier.dart
    │   ├── currency_converter.dart
    │   ├── recurrence_expander.dart
    │   └── trip_aggregator.dart
    ├── ports/                 # Interfaces (depend inward, never outward)
    │   ├── data_source.dart       # XpenslyDataSource
    │   ├── payment_provider.dart  # XpenslyPaymentProvider
    │   └── rate_provider.dart     # RateProvider
    ├── adapters/              # Built-in port implementations
    │   ├── in_memory_data_source.dart   # only data source that ships today
    │   ├── fixed_rate_provider.dart     # implements RateProvider
    │   ├── venmo_payment.dart
    │   ├── upi_payment.dart
    │   ├── paypal_payment.dart
    │   ├── stripe_payment.dart
    │   └── razorpay_payment.dart
    └── xpensly.dart           # SDK entry point (Xpensly class)
```

## Key Types

```dart
enum SplitMode { equal, exact, percentage, shares }

// Instantiate the SDK
final xpensly = Xpensly(
  dataSource: InMemoryDataSource(),
  paymentProviders: [VenmoPayment(), UpiPayment()],
  config: XpenslyConfig(baseCurrency: 'EUR', simplifyDebts: true),
);
```

## Ports

| Port | Interface | Built-in impl |
|------|-----------|---------------|
| Data persistence | `XpenslyDataSource` | `InMemoryDataSource` |
| Payment dispatch | `XpenslyPaymentProvider` | `VenmoPayment`, `UpiPayment`, `PaypalPayment`, `StripePayment`, `RazorpayPayment` |
| Exchange rates | `RateProvider` | `FixedRateProvider` |

**CRITICAL:** `SupabaseDataSource` does NOT exist. The root CLAUDE.md previously claimed a stub — that was wrong. Only `InMemoryDataSource` ships. If you need Supabase persistence, implement `XpenslyDataSource` in your app layer.

## Engine Modules

- `SplitCalculator` — distributes an expense amount across members by SplitMode
- `SettlementEngine` — computes who owes whom across a trip's expenses
- `DebtSimplifier` — graph-based minimum-transaction simplification (default); pairwise toggle available
- `CurrencyConverter` — delegates to `RateProvider`, normalises amounts to `baseCurrency`
- `RecurrenceExpander` — expands recurring expense rules into concrete Expense instances
- `TripAggregator` — rolls up per-expense data into `TripSummary`

## Invariants

- No `dart:ui` or `package:flutter` imports — enforced by `dart analyze` on a Flutter-free SDK.
- Split mode `exact` requires per-member amounts that sum to the expense total; calculator throws if they don't.
- Debt simplifier guarantees ≤ N-1 transactions for N members.
- `FixedRateProvider` takes a static rate map; it does not make network calls.
