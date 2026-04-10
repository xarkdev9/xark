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

void main() {
  group('SplitModeToggle', () {
    testWidgets('renders all available modes as chips', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        SplitModeToggle(
          selected: SplitMode.equal,
          available: SplitMode.values,
          onChanged: (_) {},
        ),
      ));

      expect(find.text('Equal'), findsOneWidget);
      expect(find.text('Exact'), findsOneWidget);
      expect(find.text('Percent'), findsOneWidget);
      expect(find.text('Shares'), findsOneWidget);
    });

    testWidgets('tapping a chip fires onChanged with correct mode',
        (tester) async {
      SplitMode? selectedMode;

      await tester.pumpWidget(buildTestWidget(
        SplitModeToggle(
          selected: SplitMode.equal,
          available: SplitMode.values,
          onChanged: (mode) => selectedMode = mode,
        ),
      ));

      await tester.tap(find.text('Percent'));
      expect(selectedMode, SplitMode.percentage);

      await tester.tap(find.text('Shares'));
      expect(selectedMode, SplitMode.shares);
    });

    testWidgets('selected mode is visually distinct', (tester) async {
      final theme = XpenslyThemeData.material();

      await tester.pumpWidget(buildTestWidget(
        SplitModeToggle(
          selected: SplitMode.exact,
          available: SplitMode.values,
          onChanged: (_) {},
        ),
      ));

      // The selected chip ("Exact") should have primary color background.
      // The unselected chip ("Equal") should have surface color background.
      // We verify by finding the Container decorations.
      final containers = tester.widgetList<Container>(find.byType(Container));
      final decoratedContainers = containers.where((c) {
        final decoration = c.decoration;
        if (decoration is BoxDecoration) {
          return decoration.color == theme.primary;
        }
        return false;
      });

      // Exactly one chip should be highlighted with primary color.
      expect(decoratedContainers.length, 1);
    });
  });
}
