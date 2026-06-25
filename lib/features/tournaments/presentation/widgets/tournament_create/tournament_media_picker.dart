import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/cf_colors.dart';
import '../../../../teams/presentation/utils/team_image_upload.dart';

class TournamentMediaPicker extends StatelessWidget {
  const TournamentMediaPicker({
    super.key,
    required this.bannerFile,
    required this.logoFile,
    required this.onBannerPicked,
    required this.onLogoPicked,
    this.existingBannerUrl,
    this.existingLogoUrl,
  });

  final File? bannerFile;
  final File? logoFile;
  final ValueChanged<File?> onBannerPicked;
  final ValueChanged<File?> onLogoPicked;
  final String? existingBannerUrl;
  final String? existingLogoUrl;

  Future<void> _pickImage(BuildContext context, {required bool isLogo}) async {
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

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () => _pickImage(context, isLogo: false),
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
                      Icon(Icons.image_outlined, color: cf.textMuted, size: 36),
                      const SizedBox(height: 6),
                      Text('Add banner', style: TextStyle(color: cf.textMuted)),
                    ],
                  ),
          ),
        ),
        Positioned(
          left: AppDimens.spaceMd,
          bottom: -36,
          child: GestureDetector(
            onTap: () => _pickImage(context, isLogo: true),
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
                              ? CachedNetworkImageProvider(existingLogoUrl!)
                              : null,
                      child: !hasLogo
                          ? Icon(Icons.emoji_events, color: cf.accent, size: 32)
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: cf.accent,
                        child: Icon(Icons.camera_alt, size: 14, color: cf.onAccent),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Add logo', style: TextStyle(fontSize: 11, color: cf.textMuted)),
              ],
            ),
          ),
        ),
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
