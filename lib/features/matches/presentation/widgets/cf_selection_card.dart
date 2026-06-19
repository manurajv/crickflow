import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';

/// Reference-style selectable card (toss, bat/bowl, squad role).
class CfSelectionCard extends StatelessWidget {
  const CfSelectionCard({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.avatarLetter,
    this.imageUrl,
    this.icon,
    this.subtitle,
    this.width = 140,
    this.height = 130,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final String? avatarLetter;
  final String? imageUrl;
  final IconData? icon;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: cf.card,
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        shadowColor: cf.cardShadow,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? cf.accent : cf.border,
                width: selected ? 2 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: cf.accent.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: cf.cardShadow,
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null)
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: cf.accent.withValues(alpha: 0.12),
                    child: Icon(icon, color: cf.accent, size: 28),
                  )
                else
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: cf.accent,
                    backgroundImage: imageUrl != null
                        ? CachedNetworkImageProvider(imageUrl!)
                        : null,
                    child: imageUrl == null
                        ? Text(
                            avatarLetter ?? '?',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                const SizedBox(height: 10),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? cf.accent : cf.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 11,
                      color: cf.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
