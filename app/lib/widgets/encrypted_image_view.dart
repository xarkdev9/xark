import 'dart:convert';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import '../theme.dart';
import '../main.dart'; // engineProvider

// Temporary local stub for a missing engine method described by the Plan
class LocalDownloadProgress {
  final DownloadPhase phase;
  final String localPath;
  LocalDownloadProgress(this.phase, this.localPath);
}

extension ChatEngineMediaExt on ChatEngine {
  Stream<LocalDownloadProgress> downloadMedia(MediaMetadata metadata) async* {
    // TODO: Connect this to actual backend pipeline when fe2ee upgrades
    yield LocalDownloadProgress(DownloadPhase.done, '/dev/null'); 
  }
}

class EncryptedImageView extends ConsumerStatefulWidget {
  final MediaMetadata metadata;
  final String? inlineThumbnail;
  final bool fillContainer;

  const EncryptedImageView({
    super.key,
    required this.metadata,
    this.inlineThumbnail,
    this.fillContainer = false,
  });

  @override
  ConsumerState<EncryptedImageView> createState() => _EncryptedImageViewState();
}

class _EncryptedImageViewState extends ConsumerState<EncryptedImageView> {
  bool _loading = true;
  bool _failed = false;
  File? _decryptedFile;

  @override
  void initState() {
    super.initState();
    _executeDecryptionPipeline();
  }

  Future<void> _executeDecryptionPipeline() async {
    try {
      final engine = ref.read(engineProvider);
      
      await for (final progress in engine.downloadMedia(widget.metadata)) {
        if (progress.phase == DownloadPhase.done) {
          if (mounted) {
            setState(() {
              _decryptedFile = File(progress.localPath);
              _loading = false;
            });
          }
          break;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  Widget _buildBlurredThumbnail() {
    if (widget.inlineThumbnail != null && widget.inlineThumbnail!.isNotEmpty) {
      try {
        String base64Str = widget.inlineThumbnail!;
        if (base64Str.contains(',')) {
          base64Str = base64Str.split(',').last;
        }
        final decodedBytes = base64Decode(base64Str);
        
        return Stack(
          fit: StackFit.expand,
          children: [
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
              child: Transform.scale(
                scale: 1.05,
                child: Image.memory(
                  decodedBytes,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Container(
              color: Colors.black.withValues(alpha: 0.15),
            ),
          ],
        );
      } catch (e) {
        // Fallback handled below
      }
    }
    
    return Container(
      color: HelloColors.chrome,
      alignment: Alignment.center,
      child: const CircularProgressIndicator(strokeWidth: 2.0, color: HelloColors.accent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = widget.fillContainer ? BorderRadius.zero : BorderRadius.circular(12.0);

    // Target 7: Graceful Degradation (Zero-Box / No-Bold)
    final Widget failedState = Container(
      decoration: BoxDecoration(
        color: HelloColors.recessed,
        borderRadius: borderRadius,
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.lock_outline, color: HelloColors.inkTertiary, size: 24),
          SizedBox(height: 8),
          Text(
            'decryption failed',
            style: TextStyle(
              fontSize: 13.0,
              fontWeight: FontWeight.w400,
              color: HelloColors.inkSecondary,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );

    // Target 6: The CSS-to-Native Blur Transition (AnimatedCrossFade)
    return ClipRRect(
      borderRadius: borderRadius,
      child: AnimatedCrossFade(
        duration: const Duration(milliseconds: 300),
        crossFadeState: _loading 
            ? CrossFadeState.showFirst 
            : CrossFadeState.showSecond,
        firstChild: _buildBlurredThumbnail(),
        secondChild: _failed 
            ? failedState 
            : (kIsWeb && widget.metadata.downloadUrl != null
                ? Image.network(widget.metadata.downloadUrl!, fit: BoxFit.cover)
                : (_decryptedFile != null 
                    ? Image.file(_decryptedFile!, fit: BoxFit.cover) 
                    : const SizedBox.shrink())),
        layoutBuilder: (topChild, topKey, bottomChild, bottomKey) {
          // Explicitly expanding children fixes sizing pops since images might bound differently natively
          return Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              Positioned.fill(key: bottomKey, child: bottomChild),
              Positioned.fill(key: topKey, child: topChild),
            ],
          );
        },
      ),
    );
  }
}
