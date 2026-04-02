# Xpensly SDK Design Spec

**Date:** 2026-04-02
**Status:** Approved
**Extracted from:** hello's settlement ledger (`web/src/lib/ledger.ts`, `Blueprint.tsx`)

## Overview

Xpensly is a reusable expense-splitting SDK extracted from hello's settlement engine. It provides split calculation, debt simplification, multi-currency support, payment deep links, and pre-built Flutter UI components. Any app can integrate via the Dart packages (Flutter) or REST API (any language/backend).

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Name | **Xpensly** | Instantly communicates "expense" management, brandable, globally neutral |
| Architecture | 3-layer: `xpensly_core` + `xpensly_ui` + REST API | Maximum reach: Flutter-native + any-language via API |
| Split models | Equal, exact, percentage, shares | Splitwise parity from day one |
| Debt simplification | Graph-based minimum-transaction (default), pairwise toggle | Better UX for groups of 5+, user can toggle to simple mode |
| Payment layer | Deep links + pluggable `PaymentProvider` interface | Ships with Venmo/UPI/PayPal, consumers plug in Stripe/Razorpay/any |
| Data layer | `XpenslyDataSource` abstract interface | Ships with Supabase + InMemory adapters. Any backend can implement. |
| Flutter UI | Opinionated hello aesthetic (default) + composable widgets with style overrides + builder callbacks | Works in hello today, drop into any app with custom theme |
| REST API backend | TypeScript via Next.js API routes in `web/` | Zero new infra, same Vercel deployment, JWT auth already solved |
| Database | New `xpensly_*` tables in Supabase Postgres | Clean separation from `decision_items`, RLS via `auth.jwt()->>'sub'` |

---

## 1. Architecture

```
Consumers: Flutter App | React App | Python | Any HTTP Client
                |              |           |
                v              v           v
         ┌────────────┐  ┌─────────────────────┐
         │ xpensly_ui │  │  Xpensly REST API   │
         │  (Flutter)  │  │  (Next.js routes)   │
         └─────┬──────┘  └─────────────────────┘
               │
               v
         ┌──────────────────────────┐
         │     xpensly_core         │
         │     (Pure Dart)          │
         └──────────────────────────┘
```

**Three deliverables:**

| Package | Language | Purpose | Consumers |
|---------|----------|---------|-----------|
| `xpensly_core` | Pure Dart (no Flutter) | Split engine, debt simplifier, adapter interfaces | Flutter apps, Dart servers, CLI tools |
| `xpensly_ui` | Flutter (depends on core) | Composable themed widgets | Flutter apps |
| `web/src/app/api/xpensly/` | TypeScript (Next.js) | REST API endpoints | Any language, any platform |

---

## 2. REST API Endpoints

### Stateless Calculation Endpoints (no auth, no DB)

```
POST /api/xpensly/calculate
  Body: {
    members: [{ id, name }],
    expenses: [{
      title, amount, currency,
      paidBy: [{ userId, amount }],
      splitAmong: [userId, ...],
      splitMode: "equal" | "exact" | "percentage" | "shares",
      splitDetails?: { [userId]: number },
      category?, date?, tags?: []
    }],
    baseCurrency: "EUR",
    exchangeRates?: { "CHF": 0.94, "GBP": 1.17 }
  }
  Returns: {
    entries: [{ userId, name, totalPaid, totalOwes, netBalance, items }],
    deltas: [{ from, to, amount, currency }],
    totalSpent, perPerson,
    byCurrency: { EUR: 4200, CHF: 800, GBP: 350 },
    byCategory: { flights: 3200, food: 1800, ... }
  }

POST /api/xpensly/simplify
  Body: { deltas, mode: "simplified" | "pairwise" }
  Returns: {
    simplified: [{ from, to, amount }],
    original: { transactionCount },
    optimized: { transactionCount, saved }
  }

POST /api/xpensly/split
  Body: {
    amount, currency?,
    paidBy: [{ userId, amount }],
    splitAmong: [userId, ...],
    mode: "equal" | "exact" | "percentage" | "shares",
    details?: { [userId]: number }
  }
  Returns: { splits: [{ userId, owes, to }] }

POST /api/xpensly/payment-link
  Body: { provider, from, to, amount, currency, note, metadata? }
  Returns: { url, qrData?, provider }

POST /api/xpensly/convert
  Body: { amount, from: "CHF", to: "EUR", rate?: number }
  Returns: { converted, rate, source: "provided" | "market" }
```

### Trip/Project Management Endpoints (stateful, JWT)

```
POST   /api/xpensly/trip
  Body: {
    title, groupId?, baseCurrency, startDate, endDate,
    phases?: [{ name, startDate, endDate }],
    members: [{ userId, name }],
    categories?: [...]
  }
  Returns: { tripId, created }

GET    /api/xpensly/trip/[tripId]
PATCH  /api/xpensly/trip/[tripId]
DELETE /api/xpensly/trip/[tripId]
```

### Expense CRUD (scoped to trip)

```
POST   /api/xpensly/trip/[tripId]/expense
  Body: {
    title, amount, currency,
    paidBy: [{ userId, amount }],
    splitAmong: [...], splitMode, category?, phase?, date,
    recurring?: { frequency, until },
    notes?, receiptUrl?, tags?: []
  }
  Returns: { expenseId, splits, runningBalances }

GET    /api/xpensly/trip/[tripId]/expenses
  Query: ?category=food&phase=during&from=2026-07-05&to=2026-07-10&paidBy=ram

PATCH  /api/xpensly/trip/[tripId]/expense/[expenseId]
DELETE /api/xpensly/trip/[tripId]/expense/[expenseId]

POST   /api/xpensly/trip/[tripId]/refund
  Body: { originalExpenseId?, amount, currency, refundedTo, reason, date }
```

### Balances & Settlement

```
GET    /api/xpensly/trip/[tripId]/balances
  Query: ?asOf=2026-07-08

GET    /api/xpensly/trip/[tripId]/summary
  Returns: { totalSpent, byCurrency, byCategory, byPhase, byMember,
             topPayer, topSpender, avgPerDay, avgPerPerson, timeline }

POST   /api/xpensly/trip/[tripId]/settle
  Body: { fromUser, toUser, amount, currency, provider?, proof?, note? }

GET    /api/xpensly/trip/[tripId]/settlements

PATCH  /api/xpensly/trip/[tripId]/settings
  Body: { simplifyDebts, baseCurrency?, defaultSplitMode? }
```

### Reference

```
GET  /api/xpensly/split-modes
GET  /api/xpensly/payment-providers
GET  /api/xpensly/currencies
GET  /api/xpensly/health
```

---

## 3. Core Engine (`xpensly_core`)

### Data Models

```dart
enum SplitMode { equal, exact, percentage, shares }

class Member { String id; String name; }

class Expense {
  String id, title, category;
  double amount; String currency;
  List<Payer> paidBy;
  List<String> splitAmong;
  SplitMode mode;
  Map<String, double>? details;
  DateTime date;
  String? phase, notes, receiptUrl;
  Recurrence? recurring;
  List<String> tags;
}

class Payer { String userId; double amount; }
class Recurrence { String frequency; DateTime until; }
class Split { String userId; double owes; String owesTo; }
class DebtDelta { String from, to; double amount; String currency; }

class LedgerEntry {
  String userId, name;
  double totalPaid, totalOwes, netBalance;
  List<ExpenseItem> items;
}

class Settlement {
  List<LedgerEntry> entries;
  List<DebtDelta> deltas;
  List<DebtDelta> simplified;
  double totalSpent, perPerson;
  Map<String, double> byCurrency, byCategory;
  int memberCount;
}

class TripSummary {
  double totalSpent;
  Map<String, double> byCurrency, byCategory, byPhase, byMember;
  String topPayer, topSpender;
  double avgPerDay, avgPerPerson;
  List<DailyTotal> timeline;
}

class Refund {
  String id; String? originalExpenseId;
  double amount; String currency, refundedTo, reason;
  DateTime date;
}
```

### Engine Classes

```dart
class SplitCalculator {
  List<Split> calculate(Expense expense);
}

class SettlementEngine {
  Settlement compute({
    required List<Member> members,
    required List<Expense> expenses,
    List<Refund> refunds,
    List<SettlementRecord> priorSettlements,
    required String baseCurrency,
    Map<String, double> exchangeRates,
  });
  Settlement computeAsOf({...same args..., required DateTime asOf});
}

class DebtSimplifier {
  List<DebtDelta> simplify(List<DebtDelta> deltas);
  List<DebtDelta> pairwise(List<DebtDelta> deltas);
}

class CurrencyConverter {
  double convert(double amount, String from, String to, Map<String, double> rates);
}

class RecurrenceExpander {
  List<Expense> expand(Expense recurring);
}

class TripAggregator {
  TripSummary summarize({
    required List<Expense> expenses,
    required List<Member> members,
    required String baseCurrency,
    Map<String, double> exchangeRates,
  });
}
```

### Adapter Interfaces

```dart
abstract class XpenslyDataSource {
  Future<List<Expense>> fetchExpenses(String tripId, {ExpenseFilter? filter});
  Future<Expense> addExpense(String tripId, Expense expense);
  Future<Expense> updateExpense(String tripId, String expenseId, Expense expense);
  Future<void> deleteExpense(String tripId, String expenseId);
  Future<List<Member>> fetchMembers(String tripId);
  Future<List<SettlementRecord>> fetchSettlements(String tripId);
  Future<SettlementRecord> recordSettlement(String tripId, SettlementRecord record);
  Future<List<Refund>> fetchRefunds(String tripId);
  Future<Refund> addRefund(String tripId, Refund refund);
}

abstract class XpenslyPaymentProvider {
  String get name;
  bool supportsQr;
  String generateLink({required String from, to, double amount, String currency, note});
  String? generateQrData({...same args...});
}

abstract class XpenslyRateProvider {
  Future<Map<String, double>> fetchRates(String baseCurrency, List<String> currencies);
}
```

### Built-in Adapters

- **DataSource:** `SupabaseDataSource`, `InMemoryDataSource`
- **Payment:** `VenmoPayment`, `UpiPayment`, `PayPalPayment`, `StripePayment`, `RazorpayPayment`
- **Rates:** `FixedRateProvider`, `OpenExchangeRateProvider`

### SDK Entry Point

```dart
class Xpensly {
  final XpenslyDataSource dataSource;
  final List<XpenslyPaymentProvider> paymentProviders;
  final XpenslyRateProvider? rateProvider;
  final XpenslyConfig config;

  Xpensly({required this.dataSource, this.paymentProviders, this.rateProvider, this.config});

  SplitCalculator get split => SplitCalculator();
  SettlementEngine get settle => SettlementEngine();
  DebtSimplifier get simplify => DebtSimplifier();
  TripAggregator get aggregate => TripAggregator();
}

class XpenslyConfig {
  final String baseCurrency;
  final SplitMode defaultSplitMode;
  final bool simplifyDebts;
}
```

---

## 4. Flutter Widgets (`xpensly_ui`)

### Theme System

```dart
class XpenslyThemeData {
  Color primary, surface, background, textPrimary, textSecondary;
  Color positive, negative, neutral;
  TextStyle titleStyle, bodyStyle, captionStyle, amountStyle;
  BorderRadius cardRadius;
  double cardElevation;

  static XpenslyThemeData hello();
  static XpenslyThemeData material();
  static XpenslyThemeData minimal();
}
```

### Widget Catalog

| Widget | Purpose | Key Props |
|--------|---------|-----------|
| `ExpenseEntry` | Add/edit expense | `members`, `onSubmit`, `categories`, `currencies`, builder overrides |
| `SettlementCard` | Full settlement summary | `settlement`, `onPaymentTap`, `simplifyToggle`, `deltaBuilder` |
| `DebtCard` | Single "X owes Y" | `delta`, `paymentProviders`, `onSettle`, `avatarBuilder` |
| `PaymentButton` | One-tap payment | `provider`, `from`, `to`, `amount`, `showQr` |
| `ExpenseList` | Filterable feed | `expenses`, `filters`, `groupBy`, `itemBuilder` |
| `BalanceBar` | Per-person balance | `userId`, `netBalance`, `currency`, `maxBalance` |
| `TripSummary` | Analytics dashboard | `summary`, `showTimeline`, `showCategoryPie` |
| `SplitModeToggle` | Mode selector | `selected`, `available`, `onChanged` |
| `XpenslyDashboard` | Full-page composed view | `xpensly`, `tripId`, `tabs`, section builder overrides |

---

## 5. Directory Structure

```
hello/
├── xpensly/
│   ├── xpensly_core/
│   │   ├── lib/
│   │   │   ├── xpensly_core.dart
│   │   │   └── src/
│   │   │       ├── models/         (member, expense, split, debt_delta, settlement, trip, refund, config)
│   │   │       ├── engine/         (split_calculator, settlement_engine, debt_simplifier, currency_converter, recurrence_expander, trip_aggregator)
│   │   │       ├── ports/          (data_source, payment_provider, rate_provider)
│   │   │       ├── adapters/       (supabase, in_memory, venmo, upi, paypal, stripe, razorpay, fixed_rate, open_exchange_rate)
│   │   │       └── xpensly.dart
│   │   └── test/
│   │       ├── engine/
│   │       ├── adapters/
│   │       └── scenarios/          (europe_trip, simple_dinner, roommates, multi_currency, solo, edge_cases)
│   │
│   └── xpensly_ui/
│       ├── lib/
│       │   ├── xpensly_ui.dart
│       │   └── src/
│       │       ├── theme/          (xpensly_theme, xpensly_theme_data, presets)
│       │       ├── widgets/        (9 widgets as listed above)
│       │       └── utils/          (formatters, animations)
│       └── test/widgets/
│
├── web/src/app/api/xpensly/
│   ├── calculate/route.ts
│   ├── simplify/route.ts
│   ├── split/route.ts
│   ├── payment-link/route.ts
│   ├── convert/route.ts
│   ├── trip/[tripId]/ ...
│   ├── split-modes/route.ts
│   ├── payment-providers/route.ts
│   ├── currencies/route.ts
│   ├── health/route.ts
│   └── lib/                        (TS mirrors of core algorithms)
```

### Deletions

| File | Action |
|------|--------|
| `web/src/lib/ledger.ts` | Replaced by `/api/xpensly` |
| `app/legacy_react_src/lib/ledger.ts` | Deleted (stale copy) |

---

## 6. Database Schema

### Tables

```sql
xpensly_trips           — trip/project container (optional group_id link)
xpensly_trip_members    — members per trip
xpensly_expenses        — individual expenses
xpensly_expense_payers  — multi-payer support (who paid)
xpensly_expense_splits  — computed splits (who owes)
xpensly_settlements     — recorded payments between users
xpensly_refunds         — refunds/credits
xpensly_exchange_rates  — cached exchange rates
```

### Key Schema Details

- All IDs: `TEXT PRIMARY KEY DEFAULT gen_random_ulid()`
- Money: `NUMERIC(12,2)` for amounts, `NUMERIC(12,6)` for exchange rates
- `xpensly_trips.group_id` is OPTIONAL (nullable FK to `groups`) — standalone SDK usage has no group link
- RLS: `auth.jwt()->>'sub'` pattern, scoped to trip membership
- Cascade deletes: trip deletion cascades to all child tables

### Migration from `decision_items`

1. New tables coexist alongside `decision_items`
2. Migration script creates `xpensly_expense` for each locked `decision_item` with a price
3. `Blueprint.tsx` switches to `/api/xpensly` endpoints
4. `ledger.ts` deleted

---

## 7. Testing Strategy

| Tier | Scope | Count | Runtime |
|------|-------|-------|---------|
| 1. Unit (xpensly_core) | Pure math, zero I/O | ~60 | < 2s |
| 2. Widget (xpensly_ui) | Render + interaction | ~25 | < 5s |
| 3. Integration (API) | Routes + database | ~30 | < 15s |
| 4. Scenario | Real-world stress tests | ~20 | < 5s |
| **Total** | | **~135** | **< 30s** |

### Key Scenario Tests

- **Europe trip:** 10 people, 15 days, 5 currencies, 3 phases, 50+ expenses, sub-groups, multi-payers, recurring, mid-trip settlements, refunds, final zero-balance verification
- **Simple dinner:** 4 people, 1 expense, < 5 lines of code (ergonomics test)
- **Roommates monthly:** 3 people, 12 months recurring, partial monthly settlements
- **Edge cases:** 0 expenses, 1 member, all-same-payer, 15-member max, 500-expense performance
