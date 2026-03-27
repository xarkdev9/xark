import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';

class InlinePollWidget extends ConsumerStatefulWidget {
  final String title;

  const InlinePollWidget({
    super.key, 
    this.title = "Live Poll",
  });

  @override
  ConsumerState<InlinePollWidget> createState() => _InlinePollWidgetState();
}

class _InlinePollWidgetState extends ConsumerState<InlinePollWidget> {
  // Dummy state mimicking Postgrest arrays
  final List<Map<String, dynamic>> _options = [
    {"id": "1", "title": "Option A", "weighted_score": 10},
    {"id": "2", "title": "Option B", "weighted_score": 5},
  ];

  @override
  Widget build(BuildContext context) {
    int totalVotes = _options.fold(0, (sum, item) => sum + (item['weighted_score'] as int));

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 340),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20.0),
        border: const Border(
          left: BorderSide(color: HelloColors.accent, width: 3.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 17.0,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF111111),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: HelloColors.accent.withValues(alpha: 0.4)),
                ),
                child: const Text(
                  "LIVE",
                  style: TextStyle(
                    fontSize: 10.0,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.5,
                    color: HelloColors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          ..._options.asMap().entries.map((entry) {
            int optIndex = entry.key;
            var opt = entry.value;
            int votes = opt['weighted_score'] as int;
            double percent = totalVotes > 0 ? (votes / totalVotes) : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: GestureDetector(
                onTap: () {
                  // Target 10: Riverpod mutation mock
                  setState(() {
                    _options[optIndex]['weighted_score'] = (_options[optIndex]['weighted_score'] as int) + 5;
                  });
                },
                child: Container(
                  height: 44.0,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      Container(color: const Color(0xFFF0F0F0)),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: percent),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutExpo, // Gliding physics
                        builder: (context, val, child) {
                          return FractionallySizedBox(
                            widthFactor: val,
                            alignment: Alignment.centerLeft,
                            child: child,
                          );
                        },
                        child: Container(
                          color: HelloColors.accent.withValues(alpha: 0.8),
                        ),
                      ),
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  opt['title'] as String,
                                  style: const TextStyle(
                                    fontSize: 15.0,
                                    fontWeight: FontWeight.w400, // No bold mandate
                                    color: Color(0xFF111111),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "${(percent * 100).round()}%",
                                style: const TextStyle(
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xFF111111),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
