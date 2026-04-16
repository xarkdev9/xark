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
              padding: EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(),
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: HelloColors.inkPrimary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Settlement',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w400, letterSpacing: 1.5, color: HelloColors.inkTertiary),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            // Eyebrow — OWED TO YOU / YOU OWE
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  s.isOwedToYou
                      ? Text(
                          'OWED TO YOU',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 1.5,
                            color: HelloColors.liveGreen,
                          ),
                        )
                      : PlasmaTint(
                          child: Text(
                            'YOU OWE',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 1.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                ],
              ),
            ),
            SizedBox(height: 28),
            // Large amount display
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Padding(
                    padding: EdgeInsets.only(bottom: 14),
                    child: Text(
                      prefix,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 24,
                        fontWeight: FontWeight.w400,
                        color: HelloColors.inkPrimary.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  SizedBox(width: 4),
                  Text(
                    abs,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 72,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -2,
                      height: 1,
                      color: HelloColors.inkPrimary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            // Counterparty line
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                s.isOwedToYou
                    ? 'from ${s.counterpartyName}'
                    : 'to ${s.counterpartyName}',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: HelloColors.inkSecondary,
                ),
              ),
            ),
            SizedBox(height: 6),
            // Reason line
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                s.reason,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w300,
                  color: HelloColors.inkTertiary,
                ),
              ),
            ),
            Spacer(),
            // Primary CTA — PAY NOW (if you owe) or REMIND (if owed to you)
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HelloHaptic.confirm();
                  Navigator.of(context).pop();
                },
                child: s.isOwedToYou
                    ? Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: HelloColors.recessed,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'REMIND',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 2.5,
                            color: HelloColors.inkPrimary,
                          ),
                        ),
                      )
                    : PlasmaFill(
                        borderRadius: BorderRadius.circular(14),
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        height: 56,
                        child: Center(
                          child: Text(
                            'PAY NOW',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 2.5,
                              color: Color(0xFFF0EFF4),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}