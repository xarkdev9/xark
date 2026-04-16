import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/feed_item.dart';
import '../../../../providers/focus_sources_provider.dart';
import '../../../../services/palette_extractor.dart';
import '../../../../theme.dart';
import '../../../../utils/haptics.dart';
import '../chromatic_atmosphere.dart';
import '../plasma/plasma.dart';

/// Push a full-screen settlement detail page via iOS-style route.
void openSettlementPage(BuildContext context, SettlementFeedItem item) {
  Navigator.of(context).push(
    CupertinoPageRoute<void>(
      builder: (_) => _SettlementPage(item: item),
    ),
  );
}

class _SettlementPage extends ConsumerStatefulWidget {
  final SettlementFeedItem item;
  const _SettlementPage({required this.item});

  @override
  ConsumerState<_SettlementPage> createState() => _SettlementPageState();
}

class _SettlementPageState extends ConsumerState<_SettlementPage> {
  bool _focusPushed = false;
  Animation<double>? _routeAnim;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_focusPushed) return;
    final anim = ModalRoute.of(context)?.animation;
    _routeAnim = anim;
    anim?.addListener(_onRouteTick);
    _focusPushed = true;
    _pushFocusSource();
  }

  Future<void> _pushFocusSource() async {
    final palette = await PaletteExtractor.resolve(
      const ContentRef(kind: 'settlement'),
    );
    if (!mounted) return;
    ref.read(focusSourcesProvider.notifier).push(
          FocusSource(
            id: 'settlement_${widget.item.settlement.id}',
            palette: palette,
            priority: 50,
            routeAnimation: _routeAnim,
          ),
        );
  }

  void _onRouteTick() {
    if (!mounted) return;
    ref.read(focusSourcesProvider.notifier).touch();
  }

  @override
  void dispose() {
    _routeAnim?.removeListener(_onRouteTick);
    ref.read(focusSourcesProvider.notifier).pop(
          'settlement_${widget.item.settlement.id}',
        );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.item.settlement;
    final abs = s.amount.abs().toStringAsFixed(2);
    final prefix = s.currency == 'USD' ? '\$' : s.currency;

    return AtmosphereDensityScope(
      density: AtmosphereDensity.focus,
      child: Scaffold(
      backgroundColor: HelloColors.voidBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with back button and eyebrow
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(