import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/cf_colors.dart';
import 'team_image_crop_config.dart';

enum TeamImageKind { profile, cover, document }

/// Max output edge used for crop + pick so registration docs stay under
/// the storage size rules (5 MB docs / 2 MB photos).
const int kTeamImageMaxEdge = 1920;
const int kTeamProfileMaxEdge = 1024;

/// Pick from camera/gallery, crop (1:1 profile/logo / 16:9 cover /
/// free + presets for documents), return local JPEG file.
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
  final maxEdge = kind == TeamImageKind.cover || isDocument
      ? kTeamImageMaxEdge
      : kTeamProfileMaxEdge;
  final picked = await picker.pickImage(
    source: source,
    imageQuality: 88,
    maxWidth: maxEdge.toDouble(),
    maxHeight: maxEdge.toDouble(),
  );
  if (picked == null) return null;

  int? srcW;
  int? srcH;
  if (isDocument) {
    final size = await decodeImageSize(picked.path);
    srcW = size?.$1;
    srcH = size?.$2;
  }
  final documentPresets = documentAspectPresets(width: srcW, height: srcH);
  final cropped = await ImageCropper().cropImage(
    sourcePath: picked.path,
    maxWidth: maxEdge,
    maxHeight: maxEdge,
    // Lock 1:1 for avatars/logos and 16:9 for covers only. Documents
    // (ID, passport, registration photos) start unlocked so the user
    // can crop freely or pick a preset. Do not pass the built-in
    // original preset: UCrop encodes it as 0×1 and can fail the crop.
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
            ? (documentPresets.isNotEmpty
                ? documentPresets.first
                : CropAspectRatioPreset.ratio4x3)
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
  final file = File(cropped.path);
  if (!file.existsSync() || file.lengthSync() == 0) {
    throw Exception('The cropped photo is empty. Please try again.');
  }
  return file;
}

/// Width and height of an image file, or null if it cannot be decoded.
Future<(int, int)?> decodeImageSize(String path) async {
  try {
    final bytes = await File(path).readAsBytes();
    if (bytes.isEmpty) return null;
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final w = frame.image.width;
    final h = frame.image.height;
    frame.image.dispose();
    codec.dispose();
    if (w <= 0 || h <= 0) return null;
    return (w, h);
  } catch (_) {
    return null;
  }
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
