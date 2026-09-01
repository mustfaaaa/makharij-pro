import 'package:flutter/material.dart';

const _iconsByKey = {
  'mic': Icons.mic,
  'local_fire_department': Icons.local_fire_department,
  'star': Icons.star,
  'menu_book': Icons.menu_book,
  'school': Icons.school,
  'whatshot': Icons.whatshot,
};

class Achievement {
  final String id;
  final String title;
  final String description;
  final String iconKey;
  final bool isUnlocked;
  final double progress;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconKey,
    required this.isUnlocked,
    this.progress = 1.0,
  });

  IconData get icon => _iconsByKey[iconKey] ?? Icons.emoji_events;

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      iconKey: json['icon_key'] as String,
      isUnlocked: json['is_unlocked'] as bool,
      progress: (json['progress'] as num).toDouble(),
    );
  }
}
