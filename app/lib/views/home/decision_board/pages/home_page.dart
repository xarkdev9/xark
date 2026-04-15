import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chromatic_atmosphere.dart';

/// Home — transitional placeholder.
///
/// Phase 2 strips Home to atmosphere only. Phase 3 rebuilds the
/// cosmos surface on top of this.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const AtmosphereDensityScope(
      density: AtmosphereDensity.focus,
      child: SizedBox.expand(),
    );
  }
}
