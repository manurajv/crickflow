import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

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
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: AppColors.card,
        borderRadius: AppDimens.cardRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppDimens.cardRadius,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: AppDimens.cardRadius,
              border: Border.all(
                color: selected ? AppColors.gold : AppColors.border,
                width: selected ? 2 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.2),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null)
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primaryBlue,
                    child: Icon(icon, color: AppColors.gold, size: 28),
                  )
                else
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primaryBlue,
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
                    color: selected ? AppColors.gold : AppColors.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
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
