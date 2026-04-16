import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../models/feed_item.dart';
import '../../../../theme.dart';
import '../plasma/plasma.dart';

Future<void> openSettlementSheet(
  BuildContext context,
  SettlementFeedItem item,
) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'SettlementSheet',
    barrierColor: Colors.black.withValues(alpha: 0.28),
    transitionDuration: Duration(milliseconds: 320),
    pageBuilder: (_, __, ___) {
      return Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: SizedBox.expand(),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _SettlementSheet(item: item),
          ),
        ],
      );
    },
    transitionBuilder: (_, animation, __, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset(0, 0.06),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      );
    },
  );
}

class _SettlementSheet extends StatelessWidget {
  final SettlementFeedItem item;
  _SettlementSheet({required this.item});

  @override
  Widget build(BuildContext context) {
    final s = item.settlement;
    final height = MediaQuery.of(context).size.height * 0.82;
    final abs = s.amount.abs().toStringAsFixed(2);
    final prefix = s.currency == 'USD' ? '\$' : s.currency;

    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: HelloColors.voidBg.withValues(alpha: 0.94),
            border: Border(
              top: BorderSide(
                color: Colors.black.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
            children: [
              SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 14),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: s.isOwedToYou
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
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: HelloColors.recessed,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: HelloColors.inkSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 28),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
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
                              color: HelloColors.inkPrimary
                                  .withValues(alpha: 0.7),
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
                    SizedBox(height: 12),
                    Text(
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
                    SizedBox(height: 6),
                    Text(
                      s.reason,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w300,
                        color: HelloColors.inkTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Spacer(),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
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
      ),
    );
  }
}
