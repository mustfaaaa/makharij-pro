import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/session_result.dart';
import '../../../theme/app_colors.dart';
import '../score_badge.dart';
import 'app_card.dart';

class RecentSessionCard extends StatelessWidget {
  final SessionResult session;
  final VoidCallback? onTap;

  const RecentSessionCard({super.key, required this.session, this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.accentSurface, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(Icons.graphic_eq, size: 20, color: AppColors.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.surahName, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '${DateFormat.MMMd().add_jm().format(session.dateTime)} · ${session.errors.length} errors',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          ScoreBadge(score: session.accuracyScore),
        ],
      ),
    );
  }
}
