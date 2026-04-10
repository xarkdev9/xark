import 'package:flutter/material.dart';
import 'package:xpensly_core/xpensly_core.dart';

import '../theme/xpensly_theme.dart';
import 'split_mode_toggle.dart';

/// Form widget for creating a new expense.
///
/// Fields: title, amount, currency, paid-by (multi-select chips),
/// split-among (member chips), split mode, category. Calls [onSubmit]
/// with the constructed [Expense].
class ExpenseEntry extends StatefulWidget {
  final List<Member> members;
  final void Function(Expense expense) onSubmit;
  final SplitMode defaultMode;
  final List<String> categories;
  final List<String> currencies;

  /// Optional custom builder for the title text field.
  final Widget Function(BuildContext, TextEditingController)? titleBuilder;

  /// Optional custom builder for the amount text field.
  final Widget Function(BuildContext, TextEditingController)? amountBuilder;

  const ExpenseEntry({
    super.key,
    required this.members,
    required this.onSubmit,
    this.defaultMode = SplitMode.equal,
    this.categories = const [],
    this.currencies = const ['USD'],
    this.titleBuilder,
    this.amountBuilder,
  });

  @override
  State<ExpenseEntry> createState() => _ExpenseEntryState();
}

class _ExpenseEntryState extends State<ExpenseEntry> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  late SplitMode _splitMode;
  late String _currency;
  String? _category;
  final Set<String> _paidByIds = {};
  final Set<String> _splitAmongIds = {};

  @override
  void initState() {
    super.initState();
    _splitMode = widget.defaultMode;
    _currency = widget.currencies.isNotEmpty ? widget.currencies.first : 'USD';
    // Default: all members participate in the split.
    _splitAmongIds.addAll(widget.members.map((m) => m.id));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());
    if (title.isEmpty || amount == null || amount <= 0) return;
    if (_paidByIds.isEmpty || _splitAmongIds.isEmpty) return;

    final payers = _paidByIds.map((id) {
      // Equal split among payers for multi-payer.
      return Payer(userId: id, amount: amount / _paidByIds.length);
    }).toList();

    final expense = Expense(
      id: '', // to be assigned by data source
      title: title,
      category: _category ?? '',
      amount: amount,
      currency: _currency,
      paidBy: payers,
      splitAmong: _splitAmongIds.toList(),
      mode: _splitMode,
      date: DateTime.now(),
    );

    widget.onSubmit(expense);
  }

  @override
  Widget build(BuildContext context) {
    final theme = XpenslyTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: theme.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Add expense',
            style: theme.titleStyle.copyWith(color: theme.textPrimary),
          ),
          const SizedBox(height: 12),

          // Title
          if (widget.titleBuilder != null)
            widget.titleBuilder!(context, _titleController)
          else
            _InputField(
              controller: _titleController,
              hint: 'What was it for?',
            ),
          const SizedBox(height: 8),

          // Amount + currency
          Row(
            children: [
              Expanded(
                child: widget.amountBuilder != null
                    ? widget.amountBuilder!(context, _amountController)
                    : _InputField(
                        controller: _amountController,
                        hint: 'Amount',
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
              ),
              const SizedBox(width: 8),
              if (widget.currencies.length > 1)
                DropdownButton<String>(
                  value: _currency,
                  underline: const SizedBox.shrink(),
                  dropdownColor: theme.surface,
                  style: theme.bodyStyle.copyWith(color: theme.textPrimary),
                  items: widget.currencies
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _currency = v);
                  },
                )
              else
                Text(
                  _currency,
                  style: theme.bodyStyle.copyWith(color: theme.textSecondary),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Paid by
          Text(
            'Paid by',
            style: theme.captionStyle.copyWith(color: theme.textSecondary),
          ),
          const SizedBox(height: 4),
          _MemberChips(
            members: widget.members,
            selectedIds: _paidByIds,
            onToggle: (id) => setState(() {
              if (_paidByIds.contains(id)) {
                _paidByIds.remove(id);
              } else {
                _paidByIds.add(id);
              }
            }),
          ),
          const SizedBox(height: 12),

          // Split among
          Text(
            'Split among',
            style: theme.captionStyle.copyWith(color: theme.textSecondary),
          ),
          const SizedBox(height: 4),
          _MemberChips(
            members: widget.members,
            selectedIds: _splitAmongIds,
            onToggle: (id) => setState(() {
              if (_splitAmongIds.contains(id)) {
                _splitAmongIds.remove(id);
              } else {
                _splitAmongIds.add(id);
              }
            }),
          ),
          const SizedBox(height: 12),

          // Split mode
          SplitModeToggle(
            selected: _splitMode,
            available: SplitMode.values,
            onChanged: (mode) => setState(() => _splitMode = mode),
          ),
          const SizedBox(height: 12),

          // Category
          if (widget.categories.isNotEmpty) ...[
            DropdownButton<String>(
              value: _category,
              hint: Text(
                'Category',
                style: theme.bodyStyle.copyWith(color: theme.textSecondary),
              ),
              isExpanded: true,
              underline: const SizedBox.shrink(),
              dropdownColor: theme.surface,
              style: theme.bodyStyle.copyWith(color: theme.textPrimary),
              items: widget.categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 12),
          ],

          // Submit
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _submit,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: theme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Add expense',
                  style: theme.bodyStyle.copyWith(color: theme.surface),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;

  const _InputField({
    required this.controller,
    required this.hint,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final theme = XpenslyTheme.of(context);

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: theme.bodyStyle.copyWith(color: theme.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: theme.bodyStyle.copyWith(color: theme.textSecondary),
        filled: true,
        fillColor: theme.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

class _MemberChips extends StatelessWidget {
  final List<Member> members;
  final Set<String> selectedIds;
  final void Function(String id) onToggle;

  const _MemberChips({
    required this.members,
    required this.selectedIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = XpenslyTheme.of(context);

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: members.map((m) {
        final isSelected = selectedIds.contains(m.id);
        return GestureDetector(
          onTap: () => onToggle(m.id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected ? theme.primary : theme.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? theme.primary
                    : theme.neutral.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              m.name,
              style: theme.captionStyle.copyWith(
                color: isSelected ? theme.surface : theme.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
