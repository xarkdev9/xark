class ItineraryEvent {
  final String id;
  final String title;
  final String location;
  final DateTime startsAt;
  final List<String> memberIds;
  final String? groupId;
  final DateTime updatedAt;

  const ItineraryEvent({
    required this.id,
    required this.title,
    required this.location,
    required this.startsAt,
    required this.memberIds,
    this.groupId,
    required this.updatedAt,
  });
}
