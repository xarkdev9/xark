class Settlement {
  final String id;
  final String counterpartyId;
  final String counterpartyName;
  final double amount; // positive = they owe you, negative = you owe them
  final String currency;
  final String reason;
  final DateTime updatedAt;

  const Settlement({
    required this.id,
    required this.counterpartyId,
    required this.counterpartyName,
    required this.amount,
    required this.currency,
    required this.reason,
    required this.updatedAt,
  });

  bool get isOwedToYou => amount > 0;
}
