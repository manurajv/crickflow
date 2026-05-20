import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

/// Circular team logo picker (reference-style).
class TeamLogoPicker extends StatelessWidget {
  const TeamLogoPicker({
    super.key,
    this.logoUrl,
    this.localPlaceholder,
    this.teamName = '',
    this.onTap,
    this.size = 120,
  });

  final String? logoUrl;
  final String? localPlaceholder;
  final String teamName;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              CircleAvatar(
                radius: size / 2,
                backgroundColor: AppColors.surfaceElevated,
                backgroundImage: logoUrl != null
                    ? CachedNetworkImageProvider(logoUrl!)
                    : null,
                child: logoUrl == null
                    ? Text(
                        (localPlaceholder?.isNotEmpty == true
                                ? localPlaceholder![0]
                                : teamName.isNotEmpty
                                    ? teamName[0]
                                    : '?')
                            .toUpperCase(),
                        style: TextStyle(
                          fontSize: size * 0.35,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryBlueLight,
                        ),
                      )
                    : null,
              ),
              Container(
                width: size,
                height: size * 0.32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(size / 2),
                  ),
                ),
                child: const Text(
                  'Add',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        Text(
          'Team logo',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
