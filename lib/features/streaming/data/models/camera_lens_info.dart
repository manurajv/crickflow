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

  static const _factorTolerance = 0.08;

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

  /// Builds the back-camera zoom row: 0.5x, 1x, 2x, and 3x only.
  ///
  /// Physical lenses are mapped from focal length; missing telephoto steps use
  /// digital zoom on the 1x camera when [maxZoom] allows.
  static List<CameraLensInfo> standardZoomLenses(
    List<CameraDescription> cameras,
    double maxZoom,
  ) {
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

    final lenses = <CameraLensInfo>[..._standardBackLenses(back, maxZoom)];
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

  static int indexForZoomFactor(List<CameraLensInfo> lenses, double factor) {
    if (lenses.isEmpty) return 0;
    var best = 0;
    var bestDist = double.infinity;
    for (var i = 0; i < lenses.length; i++) {
      if (lenses[i].isFront) continue;
      final dist = (lenses[i].zoomFactor - factor).abs();
      if (dist < bestDist) {
        bestDist = dist;
        best = i;
      }
    }
    return best.clamp(0, lenses.length - 1);
  }

  /// Adds digital zoom steps on the primary back camera up to [maxZoom].
  static List<CameraLensInfo> enrichWithDigitalZoom(
    List<CameraLensInfo> lenses,
    double maxZoom,
  ) {
    if (lenses.isEmpty) return lenses;
    final back = lenses
        .where((l) => !l.isFront && !l.isDigitalZoom)
        .map((l) => l.description)
        .fold(<CameraDescription>[], (list, cam) {
      if (!list.any((c) => c.name == cam.name)) list.add(cam);
      return list;
    });
    if (back.isEmpty) return lenses;
    back.sort(_compareBackCameras);
    return [
      ..._standardBackLenses(back, maxZoom),
      ...lenses.where((l) => l.isFront),
      ...lenses.where(
        (l) => !l.isFront && !l.isDigitalZoom && l.label.startsWith('External'),
      ),
    ];
  }

  @Deprecated('Use enrichWithDigitalZoom')
  static List<CameraLensInfo> withDeviceMaxZoom(
    List<CameraLensInfo> lenses,
    double maxZoom,
  ) =>
      enrichWithDigitalZoom(lenses, maxZoom);

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

  static const _standardBackFactors = [0.5, 1.0, 2.0, 3.0];

  static List<CameraLensInfo> _standardBackLenses(
    List<CameraDescription> back,
    double maxZoom,
  ) {
    if (back.isEmpty) return const [];

    final baseFocal = _baseFocalLength(back);
    final physicalBySlot = <double, CameraDescription>{};

    for (var i = 0; i < back.length; i++) {
      final cam = back[i];
      final focal = cam.focalLengthMm;
      final rawFactor = focal != null && baseFocal != null && baseFocal > 0
          ? focal / baseFocal
          : _fallbackZoomFactor(i, back.length);
      final slot = _nearestStandardSlot(rawFactor);
      final existing = physicalBySlot[slot];
      if (existing == null) {
        physicalBySlot[slot] = cam;
        continue;
      }
      final existingFocal = existing.focalLengthMm ?? baseFocal ?? 1.0;
      final existingRaw = existingFocal / (baseFocal ?? existingFocal);
      if ((rawFactor - slot).abs() < (existingRaw - slot).abs()) {
        physicalBySlot[slot] = cam;
      }
    }

    if (!physicalBySlot.containsKey(1.0)) {
      physicalBySlot[1.0] = back[back.length ~/ 2];
    }

    final anchor = physicalBySlot[1.0]!;
    final existingFactors = physicalBySlot.keys.toSet();
    final lenses = <CameraLensInfo>[];

    for (final factor in _standardBackFactors) {
      final physical = physicalBySlot[factor];
      if (physical != null) {
        lenses.add(CameraLensInfo(
          description: physical,
          label: formatLensZoomLabel(factor),
          zoomFactor: factor,
          isFront: false,
          isUltraWide: factor <= 0.5,
          isTelephoto: factor >= 2.0,
        ));
        continue;
      }

      if ((factor == 2.0 || factor == 3.0) &&
          maxZoom >= factor - 0.01 &&
          !existingFactors.contains(factor)) {
        lenses.add(CameraLensInfo(
          description: anchor,
          label: formatLensZoomLabel(factor),
          zoomFactor: factor,
          isFront: false,
          isDigitalZoom: true,
          isTelephoto: true,
        ));
      }
    }

    return lenses;
  }

  static double _nearestStandardSlot(double rawFactor) {
    var best = 1.0;
    var bestDist = double.infinity;
    for (final slot in _standardBackFactors) {
      final dist = (rawFactor - slot).abs();
      if (dist < bestDist) {
        bestDist = dist;
        best = slot;
      }
    }
    return best;
  }

  static String formatLensZoomLabel(double factor) {
    if (factor == 0.5) return '0.5x';
    if (factor == 1) return '1x';
    if ((factor * 10).roundToDouble() == factor * 10 && factor < 10) {
      return '${factor.toStringAsFixed(1)}x';
    }
    if (factor == factor.roundToDouble() && factor >= 1) {
      return '${factor.toInt()}x';
    }
    return '${factor.toStringAsFixed(1)}x';
  }

  static List<CameraLensInfo> _labelBackCameras(List<CameraDescription> back) {
    if (back.isEmpty) return const [];

    if (back.length == 1) {
      return [
        CameraLensInfo(
          description: back.first,
          label: '1x',
          zoomFactor: 1,
          isFront: false,
        ),
      ];
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

String formatLensZoom(double factor) => CameraLensCatalog.formatLensZoomLabel(factor);
