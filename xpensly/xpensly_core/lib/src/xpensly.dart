import 'models/config.dart';
import 'models/settlement.dart';
import 'models/trip_summary.dart';
import 'engine/split_calculator.dart';
import 'engine/settlement_engine.dart';
import 'engine/debt_simplifier.dart';
import 'engine/trip_aggregator.dart';
import 'engine/currency_converter.dart';
import 'engine/recurrence_expander.dart';
import 'ports/data_source.dart';
import 'ports/payment_provider.dart';
import 'ports/rate_provider.dart';

/// Main entry point for the Xpensly SDK.
///
/// Configure with a [XpenslyDataSource], optional [XpenslyPaymentProvider]s,
/// an optional [XpenslyRateProvider], and a [XpenslyConfig].
///
/// ```dart
/// final xpensly = Xpensly(
///   dataSource: InMemoryDataSource(),
///   paymentProviders: [VenmoPayment(), UpiPayment()],
///   config: XpenslyConfig(baseCurrency: 'EUR', simplifyDebts: true),
/// );
/// ```
class Xpensly {
  final XpenslyDataSource dataSource;
  final List<XpenslyPaymentProvider> paymentProviders;
  final XpenslyRateProvider? rateProvider;
  final XpenslyConfig config;

  Xpensly({
    required this.dataSource,
    this.paymentProviders = const [],
    this.rateProvider,
    this.config = const XpenslyConfig(),
  });

  /// Split calculator for single-expense splitting.
  SplitCalculator get split => SplitCalculator();

  /// Settlement engine for computing who owes whom across all expenses.
  SettlementEngine get settle => SettlementEngine();

  /// Debt simplifier for minimizing transaction count.
  DebtSimplifier get simplify => DebtSimplifier();

  /// Trip aggregator for summary statistics.
  TripAggregator get aggregate => TripAggregator();

  /// Currency converter using configured rates.
  CurrencyConverter get converter => CurrencyConverter();

  /// Recurrence expander for recurring expenses.
  RecurrenceExpander get expander => RecurrenceExpander();

  /// Compute full settlement for a trip.
  Future<Settlement> computeTripSettlement(String tripId) async {
    final members = await dataSource.fetchMembers(tripId);
    final expenses = await dataSource.fetchExpenses(tripId);
    final refunds = await dataSource.fetchRefunds(tripId);
    final settlements = await dataSource.fetchSettlements(tripId);

    Map<String, double> rates = {};
    if (rateProvider != null) {
      final currencies = expenses.map((e) => e.currency).toSet().toList();
      rates = await rateProvider!.fetchRates(config.baseCurrency, currencies);
    }
    rates[config.baseCurrency] = 1.0;

    return settle.compute(
      members: members,
      expenses: expenses,
      refunds: refunds,
      priorSettlements: settlements,
      baseCurrency: config.baseCurrency,
      exchangeRates: rates,
      simplifier: config.simplifyDebts ? simplify : null,
      converter: converter,
    );
  }

  /// Compute trip summary statistics.
  Future<TripSummary> computeTripSummary(String tripId) async {
    final members = await dataSource.fetchMembers(tripId);
    final expenses = await dataSource.fetchExpenses(tripId);

    Map<String, double> rates = {};
    if (rateProvider != null) {
      final currencies = expenses.map((e) => e.currency).toSet().toList();
      rates = await rateProvider!.fetchRates(config.baseCurrency, currencies);
    }
    rates[config.baseCurrency] = 1.0;

    return aggregate.summarize(
      expenses: expenses,
      members: members,
      baseCurrency: config.baseCurrency,
      exchangeRates: rates,
      converter: converter,
    );
  }

  /// Get payment link for a specific debt.
  String? getPaymentLink(
    String providerName, {
    required String from,
    required String to,
    required double amount,
    required String currency,
    String? note,
  }) {
    final provider = paymentProviders.cast<XpenslyPaymentProvider?>().firstWhere(
      (p) => p!.name == providerName,
      orElse: () => null,
    );
    return provider?.generateLink(
      from: from,
      to: to,
      amount: amount,
      currency: currency,
      note: note,
    );
  }
}
