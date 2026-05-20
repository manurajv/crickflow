import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

/// Tappable option row for add-player methods (reference-style cards).
class TeamMethodCard extends StatelessWidget {
  const TeamMethodCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
    this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceSm,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppDimens.cardRadius,
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor:
                        AppColors.primaryBlue.withValues(alpha: 0.25),
                    child: Icon(icon, color: AppColors.primaryBlueLight, size: 28),
                  ),
                  const SizedBox(width: AppDimens.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              if (child != null) ...[
                const SizedBox(height: AppDimens.spaceMd),
                child!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
