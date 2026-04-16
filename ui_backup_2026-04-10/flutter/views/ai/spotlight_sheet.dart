import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme.dart';
import 'ghost_input.dart';

class HelloStreamNotifier extends Notifier<String> {
  @override
  String build() => "";

  void append(String chunk) {
    state += chunk;
  }
  
  void clear() {
    state = "";
  }
}

// State provider to hold the actively streaming string
final helloStreamProvider = NotifierProvider<HelloStreamNotifier, String>(() {
  return HelloStreamNotifier();
});

class SpotlightSheet extends ConsumerStatefulWidget {
  final String groupId;

  const SpotlightSheet({super.key, required this.groupId});

  /// Step 1: Launch via modal with transparent backgrounds
  static void show(BuildContext context, String groupId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (ctx) => SpotlightSheet(groupId: groupId),
    );
  }

  @override
  ConsumerState<SpotlightSheet> createState() => _SpotlightSheetState();
}

class _SpotlightSheetState extends ConsumerState<SpotlightSheet> {
  final ScrollController _scrollController = ScrollController();
  bool _isStreaming = false;

  void _handleSend(String prompt) async {
    if (_isStreaming || prompt.trim().isEmpty) return;

    setState(() { _isStreaming = true; });
    ref.read(helloStreamProvider.notifier).clear(); 
    
    // Step 3: The Mock Hook (Stream.periodic 50ms)
    final text = "I am hello. I cannot read your encrypted messages, but I am here to help. The zero-box architectural mandate holds strong.";
    final chunks = text.split(" ");
    
    final simulationStream = Stream.periodic(const Duration(milliseconds: 50), (count) {
      return count == chunks.length - 1 ? chunks[count] : "${chunks[count]} ";
    }).take(chunks.length);

    try {
      await for (final chunk in simulationStream) {
        if (!mounted) break;
        ref.read(helloStreamProvider.notifier).append(chunk);
        
        // Auto-scroll to bottom as chunks arrive
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 50),
            curve: Curves.easeOut,
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() { _isStreaming = false; });
        HapticFeedback.selectionClick(); // Stream completion haptic
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Step 1: BackdropFilter with blur 30.0 + 60% opacity voidBg container
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 30.0, sigmaY: 30.0),
      child: Container(
        color: HelloColors.voidBg.withValues(alpha: 0.60),
        child: SafeArea( // Ensures it doesn't cross safe margins like top-notch
          child: Padding(
            // Bottom padding to lift above the virtual keyboard naturally
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom, 
            ),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
                    child: const _AIStreamReveal(), 
                  ),
                ),
                GhostInput(
                  isStreaming: _isStreaming,
                  onSend: _handleSend,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AIStreamReveal extends ConsumerWidget {
  const _AIStreamReveal();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = ref.watch(helloStreamProvider);

    if (text.isEmpty) return const SizedBox.shrink();

    // The Typographic Reveal: Wraps the massive unboxed text
    return RepaintBoundary(
      child: Text(
        text,
        style: HelloTypography.hero.copyWith(
          height: 1.5,
          color: HelloColors.inkPrimary,
        ),
      ),
    );
  }
}
