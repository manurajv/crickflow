import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../../core/constants/enums.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/cf_colors.dart';
import '../../../../community/presentation/utils/community_image_crop.dart';
import '../../../../teams/presentation/utils/team_image_upload.dart';

class TournamentMediaPicker extends StatelessWidget {
  const TournamentMediaPicker({
    super.key,
    required this.bannerFile,
    required this.logoFile,
    required this.onBannerPicked,
    required this.onLogoPicked,
    this.thumbnailFile,
    this.thumbnailAspect = CommunityMediaAspect.landscape16x9,
    this.onThumbnailPicked,
    this.existingBannerUrl,
    this.existingLogoUrl,
    this.existingThumbnailUrl,
  });

  final File? bannerFile;
  final File? logoFile;
  final File? thumbnailFile;
  final CommunityMediaAspect thumbnailAspect;
  final ValueChanged<File?> onBannerPicked;
  final ValueChanged<File?> onLogoPicked;
  final void Function(File file, CommunityMediaAspect aspect)? onThumbnailPicked;
  final String? existingBannerUrl;
  final String? existingLogoUrl;
  final String? existingThumbnailUrl;

  Future<void> _pickBranding(
    BuildContext context, {
    required bool isLogo,
  }) async {
    await showTeamImageSourceSheet(
      context,
      onSelected: (source) async {
        final file = await pickAndCropTeamImage(
          context,
          kind: isLogo ? TeamImageKind.profile : TeamImageKind.cover,
          source: source,
        );
        if (file == null) return;
        if (isLogo) {
          onLogoPicked(file);
        } else {
          onBannerPicked(file);
        }
      },
    );
  }

  Future<void> _pickThumbnail(BuildContext context) async {
    final result = await pickAndCropCommunityImage(context);
    if (result == null) return;
    onThumbnailPicked?.call(result.file, result.aspect);
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final bannerImage = bannerFile != null
        ? DecorationImage(image: FileImage(bannerFile!), fit: BoxFit.cover)
        : (existingBannerUrl != null && existingBannerUrl!.isNotEmpty)
            ? DecorationImage(
                image: CachedNetworkImageProvider(existingBannerUrl!),
                fit: BoxFit.cover,
              )
            : null;
    final hasBanner = bannerImage != null;
    final hasLogo = logoFile != null ||
        (existingLogoUrl != null && existingLogoUrl!.isNotEmpty);
    final hasThumb = thumbnailFile != null ||
        (existingThumbnailUrl != null && existingThumbnailUrl!.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: () => _pickBranding(context, isLogo: false),
              child: Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cf.sectionBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cf.border),
                  image: bannerImage,
                ),
                child: hasBanner
                    ? null
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_outlined,
                              color: cf.textMuted, size: 36),
                          const SizedBox(height: 6),
                          Text('Add banner',
                              style: TextStyle(color: cf.textMuted)),
                        ],
                      ),
              ),
            ),
            Positioned(
              left: AppDimens.spaceMd,
              bottom: -36,
              child: GestureDetector(
                onTap: () => _pickBranding(context, isLogo: true),
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: cf.surfaceElevated,
                          backgroundImage: logoFile != null
                              ? FileImage(logoFile!)
                              : (existingLogoUrl != null &&
                                      existingLogoUrl!.isNotEmpty)
                                  ? CachedNetworkImageProvider(
                                      existingLogoUrl!,
                                    )
                                  : null,
                          child: !hasLogo
                              ? Icon(Icons.emoji_events,
                                  color: cf.accent, size: 32)
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: cf.accent,
                            child: Icon(Icons.camera_alt,
                                size: 14, color: cf.onAccent),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Add logo',
                        style: TextStyle(fontSize: 11, color: cf.textMuted)),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (onThumbnailPicked != null) ...[
          const SizedBox(height: 48),
          Text(
            'Community thumbnail *',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Shown on Community tournament posts. Choose 1:1, 16:9, 9:16, or free crop — same as posts.',
            style: TextStyle(fontSize: 12, color: cf.textMuted),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _pickThumbnail(context),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width,
                  maxHeight: thumbnailAspect == CommunityMediaAspect.portrait9x16
                      ? 280
                      : 200,
                ),
                child: AspectRatio(
                  aspectRatio: thumbnailAspect.displayRatio,
                  child: Container(
                    decoration: BoxDecoration(
                      color: cf.sectionBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: hasThumb
                            ? cf.border
                            : cf.accent.withValues(alpha: 0.5),
                      ),
                      image: thumbnailFile != null
                          ? DecorationImage(
                              image: FileImage(thumbnailFile!),
                              fit: BoxFit.cover,
                            )
                          : (existingThumbnailUrl != null &&
                                  existingThumbnailUrl!.isNotEmpty)
                              ? DecorationImage(
                                  image: CachedNetworkImageProvider(
                                    existingThumbnailUrl!,
                                  ),
                                  fit: BoxFit.cover,
                                )
                              : null,
                    ),
                    child: hasThumb
                        ? Align(
                            alignment: Alignment.bottomRight,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  thumbnailAspect.label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.crop_original,
                                  color: cf.textMuted, size: 32),
                              const SizedBox(height: 6),
                              Text(
                                'Add tournament thumbnail',
                                style: TextStyle(color: cf.textMuted),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '1:1 · 16:9 · 9:16 · Free',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: cf.textMuted,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ] else
          const SizedBox(height: 40),
      ],
    );
  }
}

class TournamentMediaPreview extends StatelessWidget {
  const TournamentMediaPreview({
    super.key,
    this.bannerUrl,
    this.logoUrl,
  });

  final String? bannerUrl;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    if (bannerUrl == null && logoUrl == null) return const SizedBox.shrink();
    return SizedBox(
      height: 80,
      child: Row(
        children: [
          if (logoUrl != null)
            CircleAvatar(
              radius: 28,
              backgroundImage: CachedNetworkImageProvider(logoUrl!),
            ),
          if (bannerUrl != null) ...[
            const SizedBox(width: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: bannerUrl!,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
