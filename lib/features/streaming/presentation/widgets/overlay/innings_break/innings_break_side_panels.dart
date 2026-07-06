import 'package:flutter/material.dart';

import '../../../../data/models/innings_break_snapshot.dart';
import '../scorebug/scorebug_tokens.dart';

/// Shared typography + colors for all innings break slides.
class InningsBreakVisuals {
  InningsBreakVisuals._();

  static const cardBg = Colors.white;
  static const rowAlt = Color(0xFFF7F7F7);
  static const textPrimary = Color(0xFF111111);
  static const textMuted = Color(0xFF757575);
  static const textFaint = Color(0xFFB0B0B0);
  static const footerBg = Color(0xFFE6E6E6);
  static const headerBg = Color(0xFFF3F3F3);
  static const divider = Color(0x14000000);
  static const highlightBlue = Color(0xFF1E88E5);
  static const sidePanelBorder = Color(0x38FFFFFF);

  static double scaleFor(double width, bool landscape) {
    final base = landscape
        ? (width / 1280).clamp(0.82, 1.18).toDouble()
        : (width / 360).clamp(0.92, 1.15).toDouble();
    return base * (landscape ? 1.12 : 1.08);
  }

  /// Slightly larger typography for post-match summary cards.
  static double postMatchScaleFor(double width, bool landscape) =>
      scaleFor(width, landscape) * (landscape ? 1.14 : 1.12);

  static double postMatchCardMaxWidth({
    required bool landscape,
    required double parentMaxWidth,
    required double screenWidth,
    required double scale,
  }) {
    if (landscape) {
      final boosted = 720 * scale;
      if (parentMaxWidth.isFinite && parentMaxWidth > 0) {
        return parentMaxWidth.clamp(0, boosted).toDouble();
      }
      return boosted;
    }
    return cardMaxWidth(
      landscape: false,
      parentMaxWidth: parentMaxWidth,
      screenWidth: screenWidth,
    );
  }

  /// Row height that fits [rowCount] rows inside [maxHeight] without overflow.
  static double rowHeightFor({
    required double maxHeight,
    required int rowCount,
    required bool landscape,
    required double scale,
  }) {
    if (rowCount <= 0 || maxHeight <= 0) return 40 * scale;
    final perRow = maxHeight / rowCount;
    final maxH = landscape ? 42.0 * scale : 36.0 * scale;
    final minH = landscape ? 18.0 * scale : 16.0 * scale;
    if (perRow <= minH) return perRow;
    return perRow.clamp(minH, maxH);
  }

  /// Fall-of-wickets table column flex weights (header + rows must match).
  static const fallOfWicketsColumnFlex = [1, 1, 1, 2, 2, 2];

  /// Fixed width for runs/balls so fielder + bowler columns stay aligned.
  static double batterRunsBallsColumnWidth(bool landscape, double scale) =>
      (landscape ? 76.0 : 68.0) * scale;

  static double headerHeight(double scale, bool landscape) =>
      (landscape ? 72 : 64) * scale;

  static double scorecardFooterHeight(double scale, bool landscape) =>
      (landscape ? 62 : 54) * scale;

  /// Portrait horizontal inset from screen edge (host + card width).
  static double portraitHorizontalInset(double scale) => 3 * scale;

  static double cardMaxWidth({
    required bool landscape,
    required double parentMaxWidth,
    required double screenWidth,
  }) {
    if (landscape) {
      return parentMaxWidth.isFinite
          ? parentMaxWidth.clamp(0, 640).toDouble()
          : 640;
    }
    if (parentMaxWidth.isFinite && parentMaxWidth > 0) {
      return parentMaxWidth;
    }
    return screenWidth - portraitHorizontalInset(scaleFor(screenWidth, false)) * 2;
  }

  /// Actual list height — shrinks for few rows, caps at [maxHeight].
  static double listContentHeight({
    required int rowCount,
    required double rowHeight,
    required double maxHeight,
    double headerHeight = 0,
  }) {
    if (rowCount <= 0) return headerHeight;
    final content = headerHeight + rowCount * rowHeight;
    return content.clamp(0.0, maxHeight);
  }

  static double compactScale(int rowCount, double scale) =>
      rowCount > 9 ? scale * 0.9 : (rowCount > 7 ? scale * 0.94 : scale);
}

/// Large chase target — right side (landscape) or above card (portrait).
class InningsBreakTargetPanel extends StatelessWidget {
  const InningsBreakTargetPanel({
    super.key,
    required this.snapshot,
    required this.tokens,
    required this.scale,
    required this.landscape,
    this.compact = false,
  });

  final InningsBreakSnapshot snapshot;
  final ScorebugTokens tokens;
  final double scale;
  final bool landscape;
  final bool compact;

  int get _chaseBalls => snapshot.chaseOvers * snapshot.ballsPerOver;

  @override
  Widget build(BuildContext context) {
    if (snapshot.target <= 0) return const SizedBox.shrink();

    final labelSize = (landscape ? (compact ? 11 : 13) : 12) * scale;
    final targetSize = (landscape ? (compact ? 52 : 64) : 46) * scale;
    final detailSize = (landscape ? (compact ? 14 : 17) : 15) * scale;
    final rrSize = (landscape ? 13 : 12) * scale;

    return Container(
      width: compact ? double.infinity : null,
      padding: EdgeInsets.symmetric(
        horizontal: (landscape ? 18 : 16) * scale,
        vertical: (landscape ? 16 : 14) * scale,
      ),
      decoration: BoxDecoration(
        color: tokens.panelBg.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8 * scale),
        border: Border.all(
          color: InningsBreakVisuals.sidePanelBorder,
          width: 1.5 * scale,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 14 * scale,
            offset: Offset(0, 4 * scale),
          ),
        ],
      ),
      child: _targetColumn(labelSize, targetSize, detailSize, rrSize),
    );
  }

  Widget _targetColumn(
    double labelSize,
    double targetSize,
    double detailSize,
    double rrSize,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'TARGET',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.88),
            fontSize: labelSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
        SizedBox(height: 6 * scale),
        Text(
          '${snapshot.target}',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: targetSize,
            fontWeight: FontWeight.w900,
            height: 1,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 8 * scale),
        Text(
          '${snapshot.chaseOvers}.0 ($_chaseBalls balls)',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.88),
            fontSize: detailSize,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (snapshot.requiredRunRate > 0) ...[
          SizedBox(height: 10 * scale),
          Text(
            'REQ RR ${snapshot.requiredRunRate.toStringAsFixed(2)}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: rrSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ],
    );
  }
}

/// First-innings recap — left side (landscape).
class InningsBreakFirstInningsPanel extends StatelessWidget {
  const InningsBreakFirstInningsPanel({
    super.key,
    required this.snapshot,
    required this.tokens,
    required this.scale,
    required this.landscape,
  });

  final InningsBreakSnapshot snapshot;
  final ScorebugTokens tokens;
  final double scale;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 18 * scale,
        vertical: 16 * scale,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(8 * scale),
        border: Border.all(
          color: InningsBreakVisuals.sidePanelBorder,
          width: 1.5 * scale,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '1ST INNINGS',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 12 * scale,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 8 * scale),
          Text(
            '${snapshot.totalRuns}/${snapshot.totalWickets}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 38 * scale,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          SizedBox(height: 6 * scale),
          Text(
            '${snapshot.overs} overs',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 15 * scale,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 10 * scale),
          Text(
            'RR ${snapshot.runRate.toStringAsFixed(2)}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 14 * scale,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
