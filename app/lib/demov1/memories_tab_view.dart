import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import 'demov1_main.dart'; // For engineProvider
import 'theme.dart';
import 'encrypted_image_view.dart';
import 'chats_tab_view.dart'; // For conversationsProvider

/// Create a session messages provider that connects to each Session's stream
final sessionMessagesProvider = StreamProvider.family<List<Message>, String>((ref, id) {
  return ref.watch(engineProvider).getSession(id).messages;
});

/// Create memoriesProvider that filters the engine's messages yielding a flat list of MediaMetadata
final memoriesProvider = Provider<AsyncValue<List<MediaMetadata>>>((ref) {
  final convosAsync = ref.watch(conversationsProvider);
  
  return convosAsync.whenData((list) {
    final allMedia = <MediaMetadata>[];
    
    for (final c in list) {
       final msgsAsync = ref.watch(sessionMessagesProvider(c.id));
       
       if (msgsAsync is AsyncData<List<Message>>) {
           allMedia.addAll(
             msgsAsync.value
                 .where((m) => m.type == MessageType.media && m.media != null)
                 .map((m) => m.media!)
           );
       }
    }
    
    return allMedia;
  });
});

class MemoriesTabView extends ConsumerWidget {
  const MemoriesTabView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memoriesAsync = ref.watch(memoriesProvider);

    return memoriesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(strokeWidth: 2.0, color: HelloColors.accent),
      ),
      error: (err, stack) => const SizedBox.shrink(),
      data: (mediaList) {
        if (mediaList.isEmpty) {
          return const Center(
            child: Text(
              "No settled memories yet.",
              style: HelloTypography.hint,
            ),
          );
        }

        return GridView.builder(
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 2.0,
            crossAxisSpacing: 2.0,
          ),
          itemCount: mediaList.length,
          itemBuilder: (context, index) {
            final metadata = mediaList[index];
            
            // CRITICAL MEMORY RULE: We MUST use EncryptedImageView to avoid OOM
            return EncryptedImageView(
              metadata: metadata,
              inlineThumbnail: metadata.inlineThumbnail,
              fillContainer: true,
            );
          },
        );
      },
    );
  }
}
