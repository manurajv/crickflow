import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/cf_colors.dart';

enum TeamImageKind { profile, cover }

/// Pick from camera/gallery, crop (1:1 profile/logo / 16:9 cover), return local file.
Future<File?> pickAndCropTeamImage(
  BuildContext context, {
  required TeamImageKind kind,
  required ImageSource source,
  String? cropTitle,
}) async {
  final isProfile = kind == TeamImageKind.profile;
  final title = cropTitle ??
      (isProfile ? 'Crop profile photo' : 'Crop cover photo');
  final cf = context.cf;
  final picker = ImagePicker();
  final picked = await picker.pickImage(
    source: source,
    imageQuality: 88,
    maxWidth: kind == TeamImageKind.cover ? 1920 : 1024,
    maxHeight: kind == TeamImageKind.cover ? 1080 : 1024,
  );
  if (picked == null) return null;
  final cropped = await ImageCropper().cropImage(
    sourcePath: picked.path,
    aspectRatio: isProfile
        ? const CropAspectRatio(ratioX: 1, ratioY: 1)
        : const CropAspectRatio(ratioX: 16, ratioY: 9),
    compressFormat: ImageCompressFormat.jpg,
    compressQuality: 85,
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: title,
        toolbarColor: cf.surface,
        toolbarWidgetColor: cf.textPrimary,
        initAspectRatio: isProfile
            ? CropAspectRatioPreset.square
            : CropAspectRatioPreset.ratio16x9,
        lockAspectRatio: true,
      ),
      IOSUiSettings(
        title: title,
        aspectRatioLockEnabled: true,
      ),
    ],
  );
  if (cropped == null) return null;
  return File(cropped.path);
}

Future<void> showTeamImageSourceSheet(
  BuildContext context, {
  required ValueChanged<ImageSource> onSelected,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Camera'),
            onTap: () {
              Navigator.pop(ctx);
              onSelected(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Gallery'),
            onTap: () {
              Navigator.pop(ctx);
              onSelected(ImageSource.gallery);
            },
          ),
        ],
      ),
    ),
  );
}
