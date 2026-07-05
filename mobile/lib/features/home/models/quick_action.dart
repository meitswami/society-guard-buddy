import 'package:flutter/material.dart';

enum QuickActionKind {
  announcements,
  societyGroups,
  visitors,
  maintenance,
  complaints,
  events,
  emergency,
}

class QuickActionItem {
  const QuickActionItem({
    required this.kind,
    required this.label,
    required this.icon,
    this.badgeCount,
    this.statusText,
    this.statusColor,
  });

  final QuickActionKind kind;
  final String label;
  final IconData icon;
  final int? badgeCount;
  final String? statusText;
  final Color? statusColor;
}
