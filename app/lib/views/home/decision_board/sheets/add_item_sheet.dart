import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/playground_provider.dart';
import '../../../../theme.dart';
import '../../../../utils/haptics.dart';
import '../plasma/plasma.dart';

/// Available demo asset images for item photo selection.
const _demoImages = [
  'assets/decide/demo_1.jpg',
  'assets/decide/demo_2.jpg',
  'assets/decide/demo_3.jpg',
  'assets/decide/bali_beach.jpg',
  'assets/decide/tokyo_kyoto.jpg',
  'assets/decide/hawaii_hotel1.jpg',
  'assets/decide/sarah_cake.jpg',
  'assets/decide/tahoe_cabin1.jpg',
  'assets/decide/family_vacation.jpg',
  'assets/decide/bali_ubud.jpg',
];

/// Opens the Add Item sheet as a general dialog overlay.
void openAddItemSheet(BuildContext context) {
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'AddItemSheet',
    barrierColor: Colors.black.withValues(alpha: 0.28),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (_, __, ___) {
      return Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: HelloGlass.whisperSigma,
                sigmaY: HelloGlass.whisperSigma,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: const _AddItemSheetContent(),
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
            begin: const Offset(0, 0.06),
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

class _AddItemSheetContent extends ConsumerStatefulWidget {
  const _AddItemSheetContent();

  @override
  ConsumerState<_AddItemSheetContent> createState() =>
      _AddItemSheetContentState();
}

class _AddItemSheetContentState extends ConsumerState<_AddItemSheetContent> {
  final _titleController = TextEditingController();
  final _categoryController = TextEditingController();
  String? _selectedPhoto;

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final category = _categoryController.text.trim().isEmpty
        ? 'Ideas'
        : _categoryController.text.trim();
    final photo = _selectedPhoto ?? '';

    HelloHaptic.confirm();
    ref
        .read(playgroundDecisionsProvider.notifier)
        .addItem(title, category, photo);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: HelloGlass.curtainSigma,
          sigmaY: HelloGlass.curtainSigma,
        ),
        child: Container(
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
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: HelloColors.inkTertiary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'ADD TO GROUP',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 1.5,
                            color: HelloColors.inkTertiary,
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
                  const SizedBox(height: 16),

                  // Photo selector — horizontal scrollable thumbnails
                  SizedBox(
                    height: 64,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _demoImages.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        final path = _demoImages[i];
                        final isSelected = _selectedPhoto == path;
                        return GestureDetector(
                          onTap: () {
                            HelloHaptic.select();
                            setState(() => _selectedPhoto = path);
                          },
                          child: isSelected
                              ? PlasmaStroke(
                                  width: 2,
                                  borderRadius: BorderRadius.circular(12),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.asset(
                                      path,
                                      width: 64,
                                      height: 64,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.asset(
                                    path,
                                    width: 64,
                                    height: 64,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title input
                  TextField(
                    controller: _titleController,
                    onChanged: (_) => setState(() {}),
                    style: HelloText.body.copyWith(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'What is this?',
                      hintStyle: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w300,
                        color: HelloColors.inkTertiary,
                      ),
                      filled: true,
                      fillColor: HelloColors.recessed,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Category input
                  TextField(
                    controller: _categoryController,
                    style: HelloText.body.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w300,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Category (e.g. hotels, restaurants)',
                      hintStyle: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w300,
                        color: HelloColors.inkTertiary,
                      ),
                      filled: true,
                      fillColor: HelloColors.recessed,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Submit button
                  GestureDetector(
                    onTap:
                        _titleController.text.trim().isNotEmpty ? _submit : null,
                    child: _titleController.text.trim().isNotEmpty
                        ? PlasmaFill(
                            borderRadius: BorderRadius.circular(12),
                            height: 48,
                            child: Center(
                              child: Text(
                                'Add to Group',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: HelloColors.recessed,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Add to Group',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                color: HelloColors.inkTertiary,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
