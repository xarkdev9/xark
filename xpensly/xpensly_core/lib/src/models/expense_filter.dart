/// Filter criteria for querying expenses.
///
/// All fields are optional. Only non-null fields are applied as filters.
class ExpenseFilter {
  final String? category;
  final String? phase;
  final String? paidBy;
  final DateTime? from;
  final DateTime? to;
  final List<String>? tags;

  const ExpenseFilter({
    this.category,
    this.phase,
    this.paidBy,
    this.from,
    this.to,
    this.tags,
  });

  /// Returns true if no filter criteria are set.
  bool get isEmpty =>
      category == null &&
      phase == null &&
      paidBy == null &&
      from == null &&
      to == null &&
      (tags == null || tags!.isEmpty);

  @override
  String toString() =>
      'ExpenseFilter(category: $category, phase: $phase, paidBy: $paidBy, '
      'from: $from, to: $to, tags: $tags)';
}
