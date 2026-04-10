import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:xpensly_core/xpensly_core.dart';
import 'package:xpensly_ui/xpensly_ui.dart';

Widget buildTestWidget(Widget child) {
  return MaterialApp(
    home: XpenslyTheme(
      theme: XpenslyThemeData.material(),
      child: Scaffold(body: child),
    ),
  );
}

class _FakeProvider implements XpenslyPaymentProvider {
  @override
  String get name => 'venmo';

  @override
  bool get supportsQr => false;

  @override
  String generateLink({
    required String from,
    required String to,
    required double amount,
    required String currency,
    String? note,
  }) =>
      'venmo://pay';

  @override
  String? generateQrData({
    required String from,
    required String to,
    required double amount,
    required String currency,
    String? note,
  }) =>
      null;
}

void main() {
  const testDelta = DebtDelta(
    from: 'Alice',
    to: 'Bob',
    amount: 25.50,
    currency: 'USD',
  );

  group('DebtCard', () {
    testWidgets('renders from/to/amount text', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        const DebtCard(delta: testDelta),
      ));

      // DebtCard uses RichText with TextSpan children, so we search
      // for the RichText widget and verify its text content.
      final richText = tester.widget<RichText>(find.byType(RichText).first);
      final fullText = richText.text.toPlainText();
      expect(fullText, contains('Alice'));
      expect(fullText, contains('Bob'));
      expect(fullText, contains('owes'));

      // Amount is rendered as a separate Text widget.
      expect(find.textContaining('\$25.50'), findsOneWidget);
    });

    testWidgets('renders payment provider buttons', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        DebtCard(
          delta: testDelta,
          paymentProviders: [_FakeProvider()],
        ),
      ));

      expect(find.text('venmo'), findsOneWidget);
    });

    testWidgets('tapping settle fires onSettle callback', (tester) async {
      DebtDelta? settledDelta;
      String? settledProvider;

      await tester.pumpWidget(buildTestWidget(
        DebtCard(
          delta: testDelta,
          paymentProviders: [_FakeProvider()],
          onSettle: (delta, provider) {
            settledDelta = delta;
            settledProvider = provider.name;
          },
        ),
      ));

      await tester.tap(find.text('venmo'));
      expect(settledDelta, testDelta);
      expect(settledProvider, 'venmo');
    });
  });
}
