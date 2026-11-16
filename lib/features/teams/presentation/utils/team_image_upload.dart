import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/cf_colors.dart';

enum TeamImageKind { profile, cover, document }

/// Pick from camera/gallery, crop (1:1 profile/logo / 16:9 cover), return local file.
Future<File?> pickAndCropTeamImage(
  BuildContext context, {
  required TeamImageKind kind,
  required ImageSource source,
  String? cropTitle,
}) async {
  final isProfile = kind == TeamImageKind.profile;
  final isDocument = kind == TeamImageKind.document;
  final title = cropTitle ??
      (isDocument
          ? 'Crop photo'
          : isProfile
              ? 'Crop profile photo'
              : 'Crop cover photo');
  final cf = context.cf;
  final picker = ImagePicker();
  final picked = await picker.pickImage(
    source: source,
    imageQuality: 88,
    maxWidth: kind == TeamImageKind.cover || isDocument ? 1920 : 1024,
    maxHeight: kind == TeamImageKind.cover || isDocument ? 1920 : 1024,
  );
  if (picked == null) return null;
  const documentPresets = <CropAspectRatioPreset>[
    CropAspectRatioPreset.original,
    CropAspectRatioPreset.square,
    CropAspectRatioPreset.ratio3x2,
    CropAspectRatioPreset.ratio4x3,
    CropAspectRatioPreset.ratio16x9,
  ];
  final cropped = await ImageCropper().cropImage(
    sourcePath: picked.path,
    // Lock 1:1 for avatars/logos and 16:9 for covers only. Documents
    // (ID, passport, registration photos) start unlocked so the user
    // can crop freely or pick a preset.
    aspectRatio: isDocument
        ? null
        : (isProfile
            ? const CropAspectRatio(ratioX: 1, ratioY: 1)
            : const CropAspectRatio(ratioX: 16, ratioY: 9)),
    compressFormat: ImageCompressFormat.jpg,
    compressQuality: 85,
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: title,
        toolbarColor: cf.surface,
        toolbarWidgetColor: cf.textPrimary,
        initAspectRatio: isDocument
            ? CropAspectRatioPreset.original
            : isProfile
                ? CropAspectRatioPreset.square
                : CropAspectRatioPreset.ratio16x9,
        lockAspectRatio: !isDocument,
        aspectRatioPresets: isDocument
            ? documentPresets
            : (isProfile
                ? const [CropAspectRatioPreset.square]
                : const [CropAspectRatioPreset.ratio16x9]),
        cropStyle: CropStyle.rectangle,
      ),
      IOSUiSettings(
        title: title,
        aspectRatioLockEnabled: !isDocument,
        resetAspectRatioEnabled: isDocument,
        aspectRatioPickerButtonHidden: !isDocument,
        aspectRatioPresets: isDocument
            ? documentPresets
            : (isProfile
                ? const [CropAspectRatioPreset.square]
                : const [CropAspectRatioPreset.ratio16x9]),
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
