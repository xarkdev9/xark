import 'dart:math';
import 'package:flutter/material.dart';
import '../theme.dart';

class AddItemSheet extends StatefulWidget {
  final String groupId;
  final void Function(String title, String category, String photoUrl) onSubmit;

  const AddItemSheet({
    super.key,
    required this.groupId,
    required this.onSubmit,
  });

  @override
  State<AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<AddItemSheet> {
  final _titleController = TextEditingController();
  final _categoryController = TextEditingController();
  String? _previewUrl;

  static const _demoImages = [
    'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?q=80&w=800&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1501281668745-f7f57925c3b4?q=80&w=800&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1504674900247-0877df9cc836?q=80&w=800&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1544161515-4ab6ce6db874?q=80&w=800&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?q=80&w=800&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1578985545062-69928b1d9587?q=80&w=800&auto=format&fit=crop',
  ];

  void _pickImage() {
    // Demo mode: pick a random Unsplash image
    setState(() {
      _previewUrl = _demoImages[Random().nextInt(_demoImages.length)];
    });
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final category = _categoryController.text.trim().isEmpty
        ? 'Ideas'
        : _categoryController.text.trim();
    final photo = _previewUrl ?? '';

    widget.onSubmit(title, category, photo);
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _titleController.text.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: HelloColors.inkTertiary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Text('add to decide', style: HelloTypography.body),
          const SizedBox(height: 16),

          // Image zone
          GestureDetector(
            onTap: _pickImage,
            child: _previewUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 16 / 10,
                      child: Image.network(_previewUrl!, fit: BoxFit.cover),
                    ),
                  )
                : Container(
                    height: 140,
                    decoration: BoxDecoration(
                      color: HelloColors.recessed,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: HelloColors.inkTertiary.withValues(alpha: 0.2),
                        width: 1.5,
                        strokeAlign: BorderSide.strokeAlignInside,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            size: 28, color: HelloColors.inkTertiary.withValues(alpha: 0.5)),
                        const SizedBox(height: 6),
                        Text(
                          'tap to add photo',
                          style: HelloTypography.hint.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 12),

          // Title input
          TextField(
            controller: _titleController,
            onChanged: (_) => setState(() {}),
            style: HelloTypography.body.copyWith(fontSize: 15),
            decoration: InputDecoration(
              hintText: 'what is this?',
              hintStyle: HelloTypography.hint,
              filled: true,
              fillColor: HelloColors.recessed,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          const SizedBox(height: 12),

          // Category input
          TextField(
            controller: _categoryController,
            style: HelloTypography.body.copyWith(fontSize: 13, fontWeight: FontWeight.w300),
            decoration: InputDecoration(
              hintText: 'category (e.g. hotels, decorations)',
              hintStyle: HelloTypography.hint.copyWith(fontSize: 13),
              filled: true,
              fillColor: HelloColors.recessed,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          const SizedBox(height: 16),

          // Submit
          GestureDetector(
            onTap: canSubmit ? _submit : null,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: canSubmit ? HelloColors.accent : HelloColors.recessed,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'add to decide',
                  style: HelloTypography.body.copyWith(
                    fontSize: 14,
                    color: canSubmit ? Colors.white : HelloColors.inkTertiary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
