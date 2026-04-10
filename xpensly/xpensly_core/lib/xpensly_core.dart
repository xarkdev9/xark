/// Xpensly Core — Pure Dart expense splitting engine.
///
/// Provides split calculations, debt simplification, multi-currency support,
/// and pluggable adapters for data, payments, and exchange rates.
library xpensly_core;

// Models
export 'src/models/member.dart';
export 'src/models/expense.dart';
export 'src/models/split_mode.dart';
export 'src/models/split_result.dart';
export 'src/models/debt_delta.dart';
export 'src/models/settlement.dart';
export 'src/models/trip.dart';
export 'src/models/refund.dart';
export 'src/models/settlement_record.dart';
export 'src/models/config.dart';
export 'src/models/trip_summary.dart';
export 'src/models/expense_filter.dart';

// Engine
export 'src/engine/split_calculator.dart';
export 'src/engine/settlement_engine.dart';
export 'src/engine/debt_simplifier.dart';
export 'src/engine/currency_converter.dart';
export 'src/engine/recurrence_expander.dart';
export 'src/engine/trip_aggregator.dart';

// Ports (interfaces)
export 'src/ports/data_source.dart';
export 'src/ports/payment_provider.dart';
export 'src/ports/rate_provider.dart';

// Adapters (built-in implementations)
export 'src/adapters/in_memory_data_source.dart';
export 'src/adapters/venmo_payment.dart';
export 'src/adapters/upi_payment.dart';
export 'src/adapters/paypal_payment.dart';
export 'src/adapters/stripe_payment.dart';
export 'src/adapters/razorpay_payment.dart';
export 'src/adapters/fixed_rate_provider.dart';

// SDK entry point
export 'src/xpensly.dart';
