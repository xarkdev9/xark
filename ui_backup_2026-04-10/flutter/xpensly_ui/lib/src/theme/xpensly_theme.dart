import 'package:flutter/widgets.dart';

import 'xpensly_theme_data.dart';

/// InheritedWidget that provides [XpenslyThemeData] to all descendant widgets.
///
/// Wrap your widget tree with [XpenslyTheme] and access the theme via
/// `XpenslyTheme.of(context)` from any child.
class XpenslyTheme extends InheritedWidget {
  /// The theme configuration for this subtree.
  final XpenslyThemeData theme;

  const XpenslyTheme({
    super.key,
    required this.theme,
    required super.child,
  });

  /// Returns the nearest [XpenslyThemeData] from the widget tree.
  ///
  /// Falls back to [XpenslyThemeData.hello] if no ancestor [XpenslyTheme]
  /// is found.
  static XpenslyThemeData of(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<XpenslyTheme>();
    return widget?.theme ?? XpenslyThemeData.hello();
  }

  @override
  bool updateShouldNotify(XpenslyTheme oldWidget) => theme != oldWidget.theme;
}
