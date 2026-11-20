import 'package:image_cropper/image_cropper.dart';

/// UCrop rejects aspect options whose X or Y is 0. The built-in
/// [CropAspectRatioPreset.original] encodes as `(null)` / `(0, 1)`, which
/// can fail or write an empty file when it is included in
/// `aspectRatioPresets`. Documents therefore use a positive ratio computed
/// from the source image for the "Original" preset, plus common sizes.
class DocumentOriginalPreset implements CropAspectRatioPresetData {
  const DocumentOriginalPreset(this.ratioX, this.ratioY);

  final int ratioX;
  final int ratioY;

  @override
  String get name => 'original';

  @override
  (int ratioX, int ratioY)? get data => (ratioX, ratioY);
}

int gcd(int a, int b) {
  var x = a.abs();
  var y = b.abs();
  while (y != 0) {
    final t = x % y;
    x = y;
    y = t;
  }
  return x == 0 ? 1 : x;
}

/// Lowest-terms positive aspect for an image. Returns null if the size
/// cannot be used as a UCrop preset.
(int, int)? reducedAspectRatio(int width, int height) {
  if (width <= 0 || height <= 0) return null;
  final g = gcd(width, height);
  return (width ~/ g, height ~/ g);
}

/// Registration docs may be up to just under 5 MB; profile photos 2 MB
/// (matches storage.rules `under5Mb` / `under2Mb`).
int registrationMaxBytes({required bool isDocument}) =>
    isDocument ? (5 * 1024 * 1024) - 1 : (2 * 1024 * 1024) - 1;

String registrationTooLargeMessage({required bool isDocument}) =>
    isDocument
        ? 'This photo is too large. Use a photo under 5 MB.'
        : 'This photo is too large. Use a photo under 2 MB.';

/// Presets for ID / passport / registration photos. Never includes the
/// built-in original (null) preset. When [width] and [height] are known,
/// a safe "Original" preset with a positive ratio is first.
List<CropAspectRatioPresetData> documentAspectPresets({
  int? width,
  int? height,
}) {
  final original = (width != null && height != null)
      ? reducedAspectRatio(width, height)
      : null;
  return [
    if (original != null) DocumentOriginalPreset(original.$1, original.$2),
    CropAspectRatioPreset.square,
    CropAspectRatioPreset.ratio3x2,
    CropAspectRatioPreset.ratio4x3,
    CropAspectRatioPreset.ratio16x9,
  ];
}
