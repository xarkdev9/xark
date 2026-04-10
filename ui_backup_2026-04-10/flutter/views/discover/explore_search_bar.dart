import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme.dart';

/// Debounced search bar for the explore tab.
///
/// Fires [onSearch] after 300ms of inactivity. Rounded, subtle background,
/// search icon on left, clear button on right when text is present.
class ExploreSearchBar extends StatefulWidget {
  final void Function(String query)? onSearch;
  final String? hintText;

  const ExploreSearchBar({
    super.key,
    this.onSearch,
    this.hintText,
  });

  @override
  State<ExploreSearchBar> createState() => _ExploreSearchBarState();
}

class _ExploreSearchBarState extends State<ExploreSearchBar> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      widget.onSearch?.call(value.trim());
    });
    setState(() {}); // Rebuild for clear button visibility
  }

  void _onClear() {
    _controller.clear();
    widget.onSearch?.call('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: HelloColors.recessed,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: TextField(
        controller: _controller,
        onChanged: _onChanged,
        style: HelloTypography.body.copyWith(
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText ?? 'Search places, activities...',
          hintStyle: HelloTypography.hint.copyWith(
            fontWeight: FontWeight.w300,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: HelloColors.inkTertiary,
            size: 20.0,
          ),
          suffixIcon: hasText
              ? GestureDetector(
                  onTap: _onClear,
                  child: const Icon(
                    Icons.close,
                    color: HelloColors.inkTertiary,
                    size: 18.0,
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 12.0,
          ),
        ),
      ),
    );
  }
}
