import 'package:equatable/equatable.dart';
import 'package:rtmp_broadcaster/camera.dart';

/// Describes a physical camera lens available on the device.
class CameraLensInfo extends Equatable {
  const CameraLensInfo({
    required this.description,
    required this.label,
    required this.zoomFactor,
    required this.isFront,
    this.isUltraWide = false,
    this.isTelephoto = false,
    this.isDigitalZoom = false,
  });

  final CameraDescription description;
  final String label;
  /// Display zoom factor (0.5, 1, 2, …) — optical or digital.
  final double zoomFactor;
  final bool isFront;
  final bool isUltraWide;
  final bool isTelephoto;
  /// When true, [zoomFactor] is applied via [CameraController.setZoom].
  final bool isDigitalZoom;

  @override
  List<Object?> get props =>
      [description.name, zoomFactor, isFront, isDigitalZoom];
}

/// Builds lens list from [availableCameras] without faking optical zoom.
class CameraLensCatalog {
  CameraLensCatalog._();

  static List<CameraLensInfo> fromCameras(List<CameraDescription> cameras) {
    final front = cameras
        .where((c) => c.lensDirection == CameraLensDirection.front)
        .toList();
    final back = cameras
        .where((c) => c.lensDirection == CameraLensDirection.back)
        .toList()
      ..sort(_compareBackCameras);
    final external = cameras
        .where((c) => c.lensDirection == CameraLensDirection.external)
        .toList();

    final lenses = <CameraLensInfo>[];

    lenses.addAll(_labelBackCameras(back));
    for (final cam in front) {
      lenses.add(CameraLensInfo(
        description: cam,
        label: 'Front',
        zoomFactor: 1,
        isFront: true,
      ));
    }
    for (var i = 0; i < external.length; i++) {
      lenses.add(CameraLensInfo(
        description: external[i],
        label: 'External ${i + 1}',
        zoomFactor: 1,
        isFront: false,
      ));
    }
    return lenses;
  }

  /// Rebuilds digital-zoom back lenses using the device max zoom from native camera.
  static List<CameraLensInfo> withDeviceMaxZoom(
    List<CameraLensInfo> lenses,
    double maxZoom,
  ) {
    if (maxZoom <= 1 || lenses.isEmpty) return lenses;

    final backPhysical = lenses.where((l) => !l.isFront && !l.isDigitalZoom);
    if (backPhysical.isNotEmpty) return lenses;

    final cam = lenses.firstWhere((l) => !l.isFront).description;
    final digital = _digitalZoomSteps(cam, maxZoom);
    final front = lenses.where((l) => l.isFront);
    final external = lenses.where(
      (l) => !l.isFront && l.description.lensDirection == CameraLensDirection.external,
    );
    return [...digital, ...front, ...external];
  }

  static int _compareBackCameras(CameraDescription a, CameraDescription b) {
    final fa = a.focalLengthMm;
    final fb = b.focalLengthMm;
    if (fa != null && fb != null) return fa.compareTo(fb);
    if (fa != null) return -1;
    if (fb != null) return 1;
    final na = int.tryParse(a.name ?? '') ?? 0;
    final nb = int.tryParse(b.name ?? '') ?? 0;
    return na.compareTo(nb);
  }

  static List<CameraLensInfo> _digitalZoomSteps(
    CameraDescription cam,
    double maxZoom,
  ) {
    final steps = <double>[1];
    if (maxZoom >= 1.5) steps.add(2);
    if (maxZoom >= 2.5) steps.add(3);
    if (maxZoom > steps.last) steps.add(maxZoom.floorToDouble());

    return steps.map((factor) {
      return CameraLensInfo(
        description: cam,
        label: formatLensZoomLabel(factor),
        zoomFactor: factor,
        isFront: false,
        isDigitalZoom: true,
      );
    }).toList();
  }

  static String formatLensZoomLabel(double factor) {
    if (factor == 0.5) return '0.5x';
    if (factor == factor.roundToDouble() && factor >= 1) {
      return '${factor.toInt()}x';
    }
    return '${factor.toStringAsFixed(1)}x';
  }

  static List<CameraLensInfo> _labelBackCameras(List<CameraDescription> back) {
    if (back.isEmpty) return const [];

    if (back.length == 1) {
      final cam = back.first;
      return _digitalZoomSteps(cam, 3);
    }

    final baseFocal = _baseFocalLength(back);
    return back.asMap().entries.map((entry) {
      final cam = entry.value;
      final focal = cam.focalLengthMm;
      final factor = focal != null && baseFocal != null && baseFocal > 0
          ? (focal / baseFocal).clamp(0.5, 10.0)
          : _fallbackZoomFactor(entry.key, back.length);
      final label = formatLensZoomLabel(factor);
      return CameraLensInfo(
        description: cam,
        label: label,
        zoomFactor: factor,
        isFront: false,
        isUltraWide: factor <= 0.6,
        isTelephoto: factor >= 1.8,
      );
    }).toList();
  }

  static double? _baseFocalLength(List<CameraDescription> back) {
    final focalLengths = back
        .map((c) => c.focalLengthMm)
        .whereType<double>()
        .toList()
      ..sort();
    if (focalLengths.isEmpty) return null;
    if (focalLengths.length == 1) return focalLengths.first;
    return focalLengths[focalLengths.length ~/ 2];
  }

  static double _fallbackZoomFactor(int index, int count) {
    return switch (count) {
      2 => index == 0 ? 1.0 : 2.0,
      3 => switch (index) {
          0 => 0.5,
          1 => 1.0,
          _ => 2.0,
        },
      _ => index == 0 ? 1.0 : 2.0 * index,
    };
  }
}
