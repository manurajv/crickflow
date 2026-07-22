import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../teams/presentation/utils/team_image_upload.dart';

/// Pick image, let user choose aspect ratio, crop, return file + aspect.
Future<({File file, CommunityMediaAspect aspect})?> pickAndCropCommunityImage(
  BuildContext context, {
  ImageSource? source,
}) async {
  ImageSource? resolved = source;
  if (resolved == null) {
    await showTeamImageSourceSheet(
      context,
      onSelected: (s) => resolved = s,
    );
    if (resolved == null) return null;
  }
  if (!context.mounted) return null;

  final aspect = await showCommunityAspectPicker(context);
  if (aspect == null || !context.mounted) return null;

  final picker = ImagePicker();
  final picked = await picker.pickImage(
    source: resolved!,
    imageQuality: 92,
    maxWidth: 2400,
    maxHeight: 2400,
  );
  if (picked == null) return null;

  final cropped = await ImageCropper().cropImage(
    sourcePath: picked.path,
    aspectRatio: aspect == CommunityMediaAspect.free
        ? null
        : CropAspectRatio(
            ratioX: switch (aspect) {
              CommunityMediaAspect.square => 1,
              CommunityMediaAspect.landscape16x9 => 16,
              CommunityMediaAspect.portrait9x16 => 9,
              CommunityMediaAspect.free => 1,
            },
            ratioY: switch (aspect) {
              CommunityMediaAspect.square => 1,
              CommunityMediaAspect.landscape16x9 => 9,
              CommunityMediaAspect.portrait9x16 => 16,
              CommunityMediaAspect.free => 1,
            },
          ),
    compressFormat: ImageCompressFormat.jpg,
    compressQuality: 90,
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: 'Crop photo',
        toolbarColor: AppColors.surface,
        toolbarWidgetColor: Colors.white,
        initAspectRatio: switch (aspect) {
          CommunityMediaAspect.square => CropAspectRatioPreset.square,
          CommunityMediaAspect.landscape16x9 => CropAspectRatioPreset.ratio16x9,
          CommunityMediaAspect.portrait9x16 => CropAspectRatioPreset.original,
          CommunityMediaAspect.free => CropAspectRatioPreset.original,
        },
        lockAspectRatio: aspect != CommunityMediaAspect.free,
      ),
      IOSUiSettings(
        title: 'Crop photo',
        aspectRatioLockEnabled: aspect != CommunityMediaAspect.free,
      ),
    ],
  );
  if (cropped == null) return null;
  return (file: File(cropped.path), aspect: aspect);
}

Future<CommunityMediaAspect?> showCommunityAspectPicker(
  BuildContext context,
) {
  return showModalBottomSheet<CommunityMediaAspect>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.spaceMd,
          0,
          AppDimens.spaceMd,
          AppDimens.spaceMd,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Choose aspect ratio',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            const SizedBox(height: AppDimens.spaceSm),
            ...CommunityMediaAspect.values.map((a) {
              return ListTile(
                title: Text(a.label),
                onTap: () => Navigator.pop(ctx, a),
              );
            }),
          ],
        ),
      ),
    ),
  );
}
