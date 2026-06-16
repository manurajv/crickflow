import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

/// Circular team logo picker (reference-style).
class TeamLogoPicker extends StatelessWidget {
  const TeamLogoPicker({
    super.key,
    this.logoUrl,
    this.localFile,
    this.localPlaceholder,
    this.teamName = '',
    this.onTap,
    this.size = 120,
  });

  final String? logoUrl;
  final File? localFile;
  final String? localPlaceholder;
  final String teamName;
  final VoidCallback? onTap;
  final double size;

  ImageProvider? get _image {
    if (localFile != null) return FileImage(localFile!);
    if (logoUrl != null) return CachedNetworkImageProvider(logoUrl!);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: image != null
                    ? AppColors.gold.withValues(alpha: 0.6)
                    : AppColors.border,
                width: 3,
              ),
            ),
            child: CircleAvatar(
              radius: size / 2,
              backgroundColor: AppColors.surfaceElevated,
              backgroundImage: image,
              child: image == null
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
