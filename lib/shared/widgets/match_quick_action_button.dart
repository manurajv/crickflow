import 'package:flutter/material.dart';

import '../../core/theme/cf_colors.dart';

/// Icon + label quick action used on match Summary and Upcoming tabs.
class MatchQuickActionButton extends StatelessWidget {
  const MatchQuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        visualDensity: VisualDensity.compact,
        foregroundColor: highlighted ? cf.accent : cf.textPrimary,
        side: BorderSide(
          color: highlighted
              ? cf.accent
              : Theme.of(context).colorScheme.outline,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: cf.accent, size: 18),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cf.textPrimary,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
