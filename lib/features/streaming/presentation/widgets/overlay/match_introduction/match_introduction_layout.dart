import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Computed geometry for the match introduction overlay.
class MatchIntroductionMetrics {
  const MatchIntroductionMetrics({
    required this.scale,
    required this.horizontalInset,
    required this.headerTop,
    required this.headerGap,
    required this.captainsTop,
    required this.captainsBottomOverlap,
    required this.estimatedBottomBandHeight,
    required this.photoHeight,
    required this.photoWidth,
    required this.photoGap,
  });

  final double scale;
  final double horizontalInset;
  final double headerTop;
  final double headerGap;
  final double captainsTop;
  final double captainsBottomOverlap;
  final double estimatedBottomBandHeight;
  final double photoHeight;
  final double photoWidth;
  final double photoGap;

  static MatchIntroductionMetrics compute({
    required bool landscape,
    required Size size,
    required bool hasVenue,
    required bool hasSchedule,
    required bool hasTournament,
  }) {
    final scale = landscape
        ? (size.width / 1280).clamp(0.65, 1.35).toDouble()
        : (size.width / 360).clamp(0.78, 1.1).toDouble();

    final horizontalInset = landscape ? 20 * scale : 0.0;
    final headerTop = landscape ? 2 * scale : 0.0;
    final headerGap = landscape ? 6 * scale : 4 * scale;
    final headerBlock = landscape ? 54 * scale : 46 * scale;

    final bottomBandHeight = _estimateBottomBandHeight(
      landscape: landscape,
      scale: scale,
      hasVenue: hasVenue,
      hasSchedule: hasSchedule,
      hasTournament: hasTournament,
    );

    final captainsTop = headerTop + headerBlock + headerGap;
    final captainsBottomOverlap = bottomBandHeight * (landscape ? 0.48 : 0.42);
    final captainsZoneHeight = math.max(
      120.0,
      size.height - captainsTop - bottomBandHeight + captainsBottomOverlap,
    );

    final photoGap = landscape ? 28 * scale : 20 * scale;
    final aspect = landscape ? 0.66 : 0.62;

    var photoHeight = captainsZoneHeight * (landscape ? 0.96 : 0.92);
    if (landscape) {
      photoHeight = math.min(photoHeight, 330 * scale);
    } else {
      photoHeight = math.min(photoHeight, size.height * 0.36);
      photoHeight = math.min(photoHeight, 260 * scale);
    }
    photoHeight = math.max(photoHeight, landscape ? 180 * scale : 145 * scale);

    var photoWidth = photoHeight * aspect;
    final maxRowWidth = size.width -
        horizontalInset * 2 -
        (landscape ? 24 * scale : 16 * scale);
    final rowWidth = photoWidth * 2 + photoGap;
    if (rowWidth > maxRowWidth) {
      photoWidth = (maxRowWidth - photoGap) / 2;
      photoHeight = photoWidth / aspect;
    }

    return MatchIntroductionMetrics(
      scale: scale,
      horizontalInset: horizontalInset,
      headerTop: headerTop,
      headerGap: headerGap,
      captainsTop: captainsTop,
      captainsBottomOverlap: captainsBottomOverlap,
      estimatedBottomBandHeight: bottomBandHeight,
      photoHeight: photoHeight,
      photoWidth: photoWidth,
      photoGap: photoGap,
    );
  }

  /// Max width for the bottom information band (fraction of screen width).
  static double bottomBandMaxWidth({
    required bool landscape,
    required double screenWidth,
    required double scale,
  }) {
    final fraction = landscape ? 0.62 : 0.84;
    final cap = landscape ? 720 * scale : screenWidth;
    return math.min(screenWidth * fraction, cap);
  }

  static double _estimateBottomBandHeight({
    required bool landscape,
    required double scale,
    required bool hasVenue,
    required bool hasSchedule,
    required bool hasTournament,
  }) {
    var height = landscape ? 108 * scale : 118 * scale;
    if (hasTournament) height += (landscape ? 16 : 14) * scale;
    if (hasVenue || hasSchedule) {
      height += (landscape ? 34 : 40) * scale;
      if (hasSchedule && hasVenue) height += 6 * scale;
    }
    return height;
  }
}
