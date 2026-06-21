import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';

/// Circular team logo picker (used in profile sheet & edit form).
///
/// When [onTap] is provided a camera-overlay edit badge is shown.
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
    if (logoUrl != null && logoUrl!.isNotEmpty) {
      return CachedNetworkImageProvider(logoUrl!);
    }
    return null;
  }

  String get _initials {
    final raw = localPlaceholder?.trim().isNotEmpty == true
        ? localPlaceholder!.trim()
        : teamName.trim();
    if (raw.isEmpty) return '?';
    final words = raw.split(RegExp(r'\s+'));
    if (words.length == 1) {
      return words[0].substring(0, words[0].length.clamp(0, 2)).toUpperCase();
    }
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final image = _image;
    final hasImage = image != null;
    final badgeSize = size * 0.28;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Logo circle
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: hasImage ? null : cf.heroGradient,
                  color: hasImage ? cf.surfaceElevated : null,
                  border: Border.all(
                    color: hasImage
                        ? cf.accent.withValues(alpha: 0.6)
                        : cf.border,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: cf.cardShadow,
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: hasImage
                      ? Image(
                          image: image,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _Initials(initials: _initials, size: size),
                        )
                      : _Initials(initials: _initials, size: size),
                ),
              ),

              // Edit badge (only when tappable)
              if (onTap != null)
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: badgeSize,
                    height: badgeSize,
                    decoration: BoxDecoration(
                      color: cf.fabBackground,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: cf.surface,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.camera_alt_outlined,
                      size: badgeSize * 0.54,
                      color: cf.fabForeground,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        Text(
          'Team logo',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: cf.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.initials, required this.size});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: Colors.white,
          fontSize: size * 0.3,
          letterSpacing: 0.5,
          height: 1,
        ),
      ),
    );
  }
}
