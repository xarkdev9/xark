import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/action_card_widget.dart';
import '../providers/action_card_provider.dart';

class ActionCarouselPage extends StatefulWidget {
  const ActionCarouselPage({super.key});

  @override
  State<ActionCarouselPage> createState() => _ActionCarouselPageState();
}

class _ActionCarouselPageState extends State<ActionCarouselPage> {
  late PageController _controller;

  @override
  void initState() {
    super.initState();
    // Maintain 0.85 to expose adjacent cards (Zero-box spatial depth)
    _controller = PageController(viewportFraction: 0.85);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _CarouselFeed(controller: _controller);
  }
}

class _CarouselFeed extends ConsumerWidget {
  final PageController controller;
  const _CarouselFeed({required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Apple-Scale Mandate: The PageView array length is mapped.
    // The underlying data updates silently in the child widgets keeping physics uninterrupted.
    final cardCount = ref.watch(
      actionCardProvider('default_space').select((asyncData) => asyncData.value?.length ?? 0)
    );

    return PageView.builder(
      controller: controller,
      itemCount: cardCount,
      itemBuilder: (context, index) {
        return _CarouselItem(index: index);
      },
    );
  }
}

class _CarouselItem extends ConsumerWidget {
  final int index;
  const _CarouselItem({required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardData = ref.watch(
      actionCardProvider('default_space').select((asyncData) {
        final list = asyncData.value;
        if (list == null || index < 0 || index >= list.length) return null;
        return list[index];
      })
    );

    if (cardData == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 24.0),
      child: ActionCardWidget(
        message: cardData,
      ),
    );
  }
}
