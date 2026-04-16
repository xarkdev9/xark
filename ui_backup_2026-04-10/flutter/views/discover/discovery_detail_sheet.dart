import 'package:flutter/material.dart';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import '../../theme.dart';

/// Bottom sheet for full item detail view.
///
/// 90% height. Image gallery (PageView), title, location, rating,
/// description, AI summary, action buttons, and tags.
class DiscoveryDetailSheet extends StatefulWidget {
  final DiscoveryItem item;
  final DiscoveryItemDetail? detail;
  final List<String> groupNames;
  final void Function(String groupId)? onAddToGroup;
  final VoidCallback? onSave;
  final VoidCallback? onDismiss;

  const DiscoveryDetailSheet({
    super.key,
    required this.item,
    this.detail,
    this.groupNames = const [],
    this.onAddToGroup,
    this.onSave,
    this.onDismiss,
  });

  /// Show as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required DiscoveryItem item,
    DiscoveryItemDetail? detail,
    List<String> groupNames = const [],
    void Function(String groupId)? onAddToGroup,
    VoidCallback? onSave,
    VoidCallback? onDismiss,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: HelloColors.chrome,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (_) => DiscoveryDetailSheet(
        item: item,
        detail: detail,
        groupNames: groupNames,
        onAddToGroup: onAddToGroup,
        onSave: onSave,
        onDismiss: onDismiss,
      ),
    );
  }

  @override
  State<DiscoveryDetailSheet> createState() => _DiscoveryDetailSheetState();
}

class _DiscoveryDetailSheetState extends State<DiscoveryDetailSheet> {
  int _currentImageIndex = 0;

  List<String> get _imageUrls {
    if (widget.detail != null && widget.detail!.imageUrls.isNotEmpty) {
      return widget.detail!.imageUrls;
    }
    if (widget.item.imageUrl != null && widget.item.imageUrl!.isNotEmpty) {
      return [widget.item.imageUrl!];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return SizedBox(
      height: screenHeight * 0.9,
      child: Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Container(
              width: 36.0,
              height: 4.0,
              decoration: BoxDecoration(
                color: HelloColors.neutralGray.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2.0),
              ),
            ),
          ),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16.0),

                  // Image gallery
                  if (_imageUrls.isNotEmpty) _buildImageGallery(),
                  if (_imageUrls.isEmpty) _buildPlaceholderImage(),

                  const SizedBox(height: 16.0),

                  // Title
                  Text(
                    widget.item.title,
                    style: HelloTypography.hero.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  // Location
                  if (widget.item.location != null) ...[
                    const SizedBox(height: 4.0),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14.0,
                          color: HelloColors.inkTertiary,
                        ),
                        const SizedBox(width: 4.0),
                        Text(
                          widget.item.location!,
                          style: HelloTypography.hint.copyWith(
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Rating + review count
                  if (widget.detail?.rating != null) ...[
                    const SizedBox(height: 8.0),
                    _buildRating(),
                  ],

                  const SizedBox(height: 16.0),

                  // Description
                  if (widget.detail?.longDescription != null)
                    Text(
                      widget.detail!.longDescription!,
                      style: HelloTypography.body.copyWith(
                        fontWeight: FontWeight.w400,
                        color: HelloColors.inkSecondary,
                      ),
                    )
                  else if (widget.item.description != null)
                    Text(
                      widget.item.description!,
                      style: HelloTypography.body.copyWith(
                        fontWeight: FontWeight.w400,
                        color: HelloColors.inkSecondary,
                      ),
                    ),

                  // AI summary
                  if (widget.detail?.aiSummary != null) ...[
                    const SizedBox(height: 16.0),
                    _buildAiSummary(),
                  ],

                  // Tags
                  if (widget.detail != null &&
                      widget.detail!.tags.isNotEmpty) ...[
                    const SizedBox(height: 16.0),
                    _buildTags(),
                  ],

                  const SizedBox(height: 24.0),

                  // Action buttons
                  _buildActions(),

                  const SizedBox(height: 32.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGallery() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12.0),
      child: SizedBox(
        height: 220.0,
        child: Stack(
          children: [
            PageView.builder(
              itemCount: _imageUrls.length,
              onPageChanged: (index) {
                setState(() => _currentImageIndex = index);
              },
              itemBuilder: (context, index) {
                return Image.network(
                  _imageUrls[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (_, e, st) => _placeholderBox(),
                );
              },
            ),
            // Page indicator
            if (_imageUrls.length > 1)
              Positioned(
                bottom: 8.0,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_imageUrls.length, (index) {
                    return Container(
                      width: index == _currentImageIndex ? 16.0 : 6.0,
                      height: 6.0,
                      margin: const EdgeInsets.symmetric(horizontal: 2.0),
                      decoration: BoxDecoration(
                        color: index == _currentImageIndex
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(3.0),
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12.0),
      child: SizedBox(
        height: 180.0,
        width: double.infinity,
        child: _placeholderBox(),
      ),
    );
  }

  Widget _placeholderBox() {
    return Container(
      color: HelloColors.recessed,
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          color: HelloColors.inkTertiary,
          size: 40.0,
        ),
      ),
    );
  }

  Widget _buildRating() {
    final rating = widget.detail!.rating!;
    final reviewCount = widget.detail?.reviewCount;

    return Row(
      children: [
        Icon(
          Icons.star,
          size: 16.0,
          color: rating >= 4.0
              ? HelloColors.seekingAmber
              : HelloColors.inkTertiary,
        ),
        const SizedBox(width: 4.0),
        Text(
          rating.toStringAsFixed(1),
          style: HelloTypography.body.copyWith(
            fontSize: 14.0,
            fontWeight: FontWeight.w400,
            color: HelloColors.inkPrimary,
          ),
        ),
        if (reviewCount != null) ...[
          const SizedBox(width: 4.0),
          Text(
            '($reviewCount reviews)',
            style: HelloTypography.hint.copyWith(
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAiSummary() {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: HelloColors.recessed.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '@hello says',
            style: HelloTypography.hint.copyWith(
              fontWeight: FontWeight.w300,
              color: HelloColors.accent,
              fontSize: 11.0,
            ),
          ),
          const SizedBox(height: 6.0),
          Text(
            widget.detail!.aiSummary!,
            style: HelloTypography.body.copyWith(
              fontWeight: FontWeight.w300,
              fontStyle: FontStyle.italic,
              color: HelloColors.inkSecondary,
              fontSize: 14.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTags() {
    return Wrap(
      spacing: 6.0,
      runSpacing: 6.0,
      children: widget.detail!.tags.map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          decoration: BoxDecoration(
            color: HelloColors.recessed,
            borderRadius: BorderRadius.circular(4.0),
          ),
          child: Text(
            tag,
            style: HelloTypography.hint.copyWith(
              fontSize: 11.0,
              fontWeight: FontWeight.w300,
              color: HelloColors.inkSecondary,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Add to group button (with dropdown if multiple groups)
        if (widget.groupNames.isNotEmpty)
          _buildAddToGroupButton(),

        const SizedBox(height: 8.0),

        // Save + Not Interested row
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: 'Save',
                icon: Icons.bookmark_outline,
                onTap: widget.onSave,
              ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: _ActionButton(
                label: 'Not interested',
                icon: Icons.close,
                onTap: () {
                  widget.onDismiss?.call();
                  Navigator.of(context).pop();
                },
                isSubtle: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAddToGroupButton() {
    if (widget.groupNames.length == 1) {
      return GestureDetector(
        onTap: () => widget.onAddToGroup?.call(widget.groupNames.first),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14.0),
          decoration: BoxDecoration(
            color: HelloColors.accent,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Center(
            child: Text(
              'Add to ${widget.groupNames.first}',
              style: HelloTypography.body.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      );
    }

    // Multiple groups: show dropdown
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      decoration: BoxDecoration(
        color: HelloColors.accent,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: DropdownButton<String>(
        isExpanded: true,
        hint: Text(
          'Add to group...',
          style: HelloTypography.body.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w400,
          ),
        ),
        icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
        underline: const SizedBox.shrink(),
        dropdownColor: HelloColors.chrome,
        items: widget.groupNames.map((name) {
          return DropdownMenuItem(
            value: name,
            child: Text(
              name,
              style: HelloTypography.body.copyWith(
                fontWeight: FontWeight.w400,
              ),
            ),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) widget.onAddToGroup?.call(value);
        },
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isSubtle;

  const _ActionButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.isSubtle = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        decoration: BoxDecoration(
          color: isSubtle ? HelloColors.recessed : HelloColors.recessed,
          borderRadius: BorderRadius.circular(8.0),
          border: isSubtle ? null : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16.0,
              color:
                  isSubtle ? HelloColors.inkTertiary : HelloColors.inkSecondary,
            ),
            const SizedBox(width: 6.0),
            Text(
              label,
              style: HelloTypography.label.copyWith(
                fontWeight: FontWeight.w400,
                color: isSubtle
                    ? HelloColors.inkTertiary
                    : HelloColors.inkSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
