import 'split_mode.dart';

/// Global configuration for the Xpensly SDK.
class XpenslyConfig {
  final String baseCurrency;
  final SplitMode defaultSplitMode;
  final bool simplifyDebts;

  const XpenslyConfig({
    this.baseCurrency = 'USD',
    this.defaultSplitMode = SplitMode.equal,
    this.simplifyDebts = true,
  });

  @override
  String toString() =>
      'XpenslyConfig(currency: $baseCurrency, mode: $defaultSplitMode, '
      'simplify: $simplifyDebts)';
}
