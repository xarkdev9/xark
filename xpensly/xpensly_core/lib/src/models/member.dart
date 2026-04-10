/// A member participating in expense splitting.
class Member {
  final String id;
  final String name;

  const Member({required this.id, required this.name});

  @override
  String toString() => 'Member(id: $id, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Member &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => Object.hash(id, name);
}
