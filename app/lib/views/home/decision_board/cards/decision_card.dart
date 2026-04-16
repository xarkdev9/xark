import 'package:flutter/material.dart';
import '../liquid_fire_consensus_burst.dart';
import '../pages/xr_media_viewer.dart';
import '../../../../../../theme.dart';
import '_card_shell.dart';

// Standalone proxy class matching the structure needed for UI prototyping
class MockPlanItem {
  final String id;
  final String title;
  final String? description;
  final String category;
  final String? photoUrl;
  final double agreementScore;
  final bool isLocked;
  final String proposedBy;
  final double weightedScore;

  const MockPlanItem({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    this.photoUrl,
    required this.agreementScore,
    required this.isLocked,
    required this.proposedBy,
    required this.weightedScore,
  });
}


class DecisionCard extends StatefulWidget {
  final MockPlanItem item;

  const DecisionCard({
    super.key,
    required this.item,
  });

  @override
  State<DecisionCard> createState() => _DecisionCardState();
}

class _DecisionCardState extends State<DecisionCard> with SingleTickerProviderStateMixin {
  double _agreementScore = 0.0;
  String? _selectedVote;
  late AnimationController _scorePulse;
  double _opacity = 1.0;

  @override
  void initState() {
    super.initState();
    _agreementScore = widget.item.agreementScore;
    _scorePulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _scorePulse.dispose();
    super.dispose();
  }

  Color _getScoreColor(double score) {
    if (score >= 0.80) return HelloColors.accent;
    if (score >= 0.50) return HelloColors.scoreHigh; // Turquoise
    return HelloColors.scoreLow; // Amber
  }

  void _handleDiscard() {
    setState(() {
      _opacity = 0.0; 
      // In a real app we would ping the backend here to lower weightedScore
      // and animate the height to 0 after the fade.
    });
  }

  void _handleIgnite() {
    setState(() {
      _selectedVote = 'love';
      _agreementScore = (_agreementScore + 0.15).clamp(0.0, 1.0);
      _scorePulse.forward(from: 0.0);
    });
  }


  @override
  Widget build(BuildContext context) {
    final bool isIgnited = _agreementScore >= 0.8;
    final photoUrl = widget.item.photoUrl;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    if (isIgnited && _selectedVote == 'love') {
      // simulate checking conditions
    }


    final cardContent = CardShell(
      id: widget.item.id,
      padding: EdgeInsets.zero,
      onTap: () {
        // Quick view or flip conceptually
      },
      backgroundImage: hasPhoto 
        ? DecorationImage(
            image: photoUrl!.startsWith('http') ? NetworkImage(photoUrl) as ImageProvider : AssetImage(photoUrl),
            fit: BoxFit.cover,
          )
        : null,
      child: GestureDetector(
        onLongPress: _handleIgnite,
        onTap: () {
          if (hasPhoto) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => XRMediaViewer(imageUrl: photoUrl)),
            );
          }
        },
        child: SizedBox(
          height: 440,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (!hasPhoto)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF2C2C2E), Color(0xFF1C1C1E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
              // Cinematic Gradient Overlay (Darkens bottom 60% for legibility)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                    stops: const [0.4, 0.65, 1.0],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // 3. Title + Score (Bottom, above the [Not for me] pill)
            Positioned(
              left: 16.0,
              bottom: 48.0, 
              right: 16.0,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isIgnited)
                           const Padding(
                             padding: EdgeInsets.only(bottom: 6.0),
                             child: _ConsensusTimer(seconds: 45),
                           ),
                        Text(
                          widget.item.title,
                          style: HelloText.title.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w400, // NO BOLD
                            fontSize: 18,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.item.description != null && widget.item.description!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.item.description!.split('\n').first,
                            style: HelloText.label.copyWith(
                              color: Colors.white.withAlpha(150),
                              fontSize: 13,
                              fontWeight: FontWeight.w300,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedBuilder(
                    animation: _scorePulse,
                    builder: (context, child) {
                      final t = _scorePulse.value;
                      final scale = 1.0 + (0.35 * t * (1.0 - t) * 4);
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: Text(
                      '${(_agreementScore * 100).toInt()}',
                      style: HelloText.display.copyWith(
                        fontSize: 32,
                        color: _getScoreColor(_agreementScore),
                        height: 1.0,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 4. Voting (Gravity Sink Pill)
            Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              child: UnconstrainedBox(
                child: GestureDetector(
                  onTap: _handleDiscard,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Text(
                      'Not for me',
                      style: HelloText.label.copyWith(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ));

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: _opacity,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
        child: _opacity == 0.0 ? const SizedBox.shrink() : Padding(
          padding: const EdgeInsets.only(bottom: 24.0),
          child: LiquidFireConsensusBurst(
            isIgnited: isIgnited,
            child: cardContent,
          ),
        ),
      ),
    );
  }
}


class _ConsensusTimer extends StatefulWidget {
  final int seconds;
  const _ConsensusTimer({required this.seconds});
  @override
  State<_ConsensusTimer> createState() => _ConsensusTimerState();
}

class _ConsensusTimerState extends State<_ConsensusTimer> with SingleTickerProviderStateMixin {
  late int _remaining;
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _remaining = widget.seconds;
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    _tick();
  }

  void _tick() async {
    while (_remaining > 0 && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) setState(() => _remaining--);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: HelloColors.gold.withAlpha((100 + 50 * _pulse.value).toInt()),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer_outlined, size: 12, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                '00:${_remaining.toString().padLeft(2, '0')}',
                style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w400, color: Colors.white),
              )
            ],
          ),
        );
      }
    );
  }
}
