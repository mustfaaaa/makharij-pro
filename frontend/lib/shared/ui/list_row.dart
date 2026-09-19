import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// One row of a settings-style list: an icon in a soft square, a title, an
/// optional subtitle and a trailing control or chevron, separated from the
/// next row by a hairline rather than boxed in a card.
class ListRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;
  final bool showDivider;

  const ListRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = destructive ? AppColors.error : AppColors.textPrimary;
    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: showDivider ? Border(bottom: BorderSide(color: AppColors.divider)) : null,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: destructive ? AppColors.errorLight : AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: destructive ? AppColors.error : AppColors.onPrimarySurface),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: textTheme.bodyLarge?.copyWith(color: color, fontWeight: FontWeight.w500)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(subtitle!, style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing ??
                  (onTap == null ? const SizedBox.shrink() : Icon(Icons.chevron_right_rounded, color: AppColors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}
