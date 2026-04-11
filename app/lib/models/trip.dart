import 'package:flutter/material.dart';

class Trip {
  final String id;
  final String destination;
  final String photoUrl;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> memberIds;
  final int pendingDecisionCount;
  final String phase; // 'planning' | 'active' | 'done'
  final Color accentColor;
  final DateTime updatedAt;

  const Trip({
    required this.id,
    required this.destination,
    required this.photoUrl,
    required this.startDate,
    required this.endDate,
    required this.memberIds,
    required this.pendingDecisionCount,
    required this.phase,
    required this.accentColor,
    required this.updatedAt,
  });
}
