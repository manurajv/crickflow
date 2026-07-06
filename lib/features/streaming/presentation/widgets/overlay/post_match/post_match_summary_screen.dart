import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'post_match_snapshot_adapter.dart';
import '../../../../data/models/post_match_snapshot.dart';
import '../../../../data/models/stream_overlay_theme.dart';
import '../innings_break/innings_break_shell.dart';
import '../innings_break/innings_break_side_panels.dart';

/// Full-match summary card — both innings, top performers, result banner.
class PostMatchSummaryScreen extends StatelessWidget {
  const PostMatchSummaryScreen({
    super.key,
    required this.snapshot,
    required this.theme,
    required this.landscape,
  });

  final PostMatchSnapshot snapshot;
  final StreamOverlayTheme theme;
  final bool landscape;

  static const resultRed = Color(0xFFB71C1C);

  @override
  Widget build(BuildContext context) {
    final scale = InningsBreakShell.postMatchScaleOf(context, landscape);

    return InningsBreakShell(
      snapshot: PostMatchSnapshotAdapter.shellSnapshot(snapshot),
      theme: theme,
      landscape: landscape,
      subtitle: 'Match Summary',
      postMatchLayout: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (snapshot.matchTypeSubtitle.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(
                14 * scale,
                8 * scale,
                14 * scale,
                4 * scale,
              ),
              child: Text(
                snapshot.matchTypeSubtitle.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: InningsBreakVisuals.textMuted,
                  fontSize: (landscape ? 12 : 11) * scale,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          for (var i = 0; i < snapshot.teams.length; i++) ...[
            if (i > 0) SizedBox(height: 8 * scale),
            _TeamSummaryBlock(
              team: snapshot.teams[i],
              scale: scale,
              landscape: landscape,
            ),
          ],
          SizedBox(height: 10 * scale),
          _ResultBanner(
            text: snapshot.resultText,
            scale: scale,
            landscape: landscape,
          ),
        ],
      ),
    );
  }
}

class _TeamSummaryBlock extends StatelessWidget {
  const _TeamSummaryBlock({
    required this.team,
    required this.scale,
    required this.landscape,
  });

  final PostMatchTeamSummary team;
  final double scale;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    final headerSize = (landscape ? 13.5 : 12) * scale;
    final cellSize = (landscape ? 11 : 10) * scale;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: InningsBreakVisuals.divider),
          bottom: BorderSide(color: InningsBreakVisuals.divider),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: InningsBreakVisuals.highlightBlue,
            padding: EdgeInsets.symmetric(
              horizontal: 12 * scale,
              vertical: 8 * scale,
            ),
            child: Row(
              children: [
                if (team.logoUrl?.isNotEmpty == true) ...[
                  SizedBox(
                    width: 22 * scale,
                    height: 22 * scale,
                    child: CachedNetworkImage(
                      imageUrl: team.logoUrl!,
                      fit: BoxFit.contain,
                    ),
                  ),
                  SizedBox(width: 8 * scale),
                ],
                Expanded(
                  child: Text(
                    '${team.teamName.toUpperCase()}${team.wonToss ? ' (TOSS)' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: headerSize,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  team.oversLabel,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: (landscape ? 10.5 : 9.5) * scale,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 10 * scale),
                Text(
                  team.score,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: (landscape ? 20 : 18) * scale,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _PlayerColumn(
                    title: 'BATTING',
                    scale: scale,
                    cellSize: cellSize,
                    children: [
                      for (var i = 0; i < 4; i++)
                        _BatterRow(
                          line: i < team.topBatters.length
                              ? team.topBatters[i]
                              : null,
                          scale: scale,
                          cellSize: cellSize,
                          alternate: i.isOdd,
                        ),
                    ],
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  color: InningsBreakVisuals.divider,
                ),
                Expanded(
                  child: _PlayerColumn(
                    title: 'BOWLING',
                    scale: scale,
                    cellSize: cellSize,
                    children: [
                      for (var i = 0; i < 4; i++)
                        _BowlerRow(
                          line: i < team.topBowlers.length
                              ? team.topBowlers[i]
                              : null,
                          scale: scale,
                          cellSize: cellSize,
                          alternate: i.isOdd,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerColumn extends StatelessWidget {
  const _PlayerColumn({
    required this.title,
    required this.scale,
    required this.cellSize,
    required this.children,
  });

  final String title;
  final double scale;
  final double cellSize;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 10 * scale,
            vertical: 5 * scale,
          ),
          child: Text(
            title,
            style: TextStyle(
              color: InningsBreakVisuals.textMuted,
              fontSize: cellSize,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}

class _BatterRow extends StatelessWidget {
  const _BatterRow({
    required this.line,
    required this.scale,
    required this.cellSize,
    required this.alternate,
  });

  final PostMatchBatterLine? line;
  final double scale;
  final double cellSize;
  final bool alternate;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: alternate ? InningsBreakVisuals.rowAlt : InningsBreakVisuals.cardBg,
      padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 5 * scale),
      child: line == null
          ? SizedBox(height: cellSize)
          : Row(
              children: [
                Expanded(
                  child: Text(
                    line!.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: InningsBreakVisuals.textPrimary,
                      fontSize: cellSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${line!.runs}${line!.isNotOut ? '*' : ''}',
                  style: TextStyle(
                    color: InningsBreakVisuals.textPrimary,
                    fontSize: cellSize + 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(width: 6 * scale),
                Text(
                  '${line!.balls}',
                  style: TextStyle(
                    color: InningsBreakVisuals.textMuted,
                    fontSize: cellSize - 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }
}

class _BowlerRow extends StatelessWidget {
  const _BowlerRow({
    required this.line,
    required this.scale,
    required this.cellSize,
    required this.alternate,
  });

  final PostMatchBowlerLine? line;
  final double scale;
  final double cellSize;
  final bool alternate;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: alternate ? InningsBreakVisuals.rowAlt : InningsBreakVisuals.cardBg,
      padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 5 * scale),
      child: line == null
          ? SizedBox(height: cellSize)
          : Row(
              children: [
                Expanded(
                  child: Text(
                    line!.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: InningsBreakVisuals.textPrimary,
                      fontSize: cellSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${line!.wickets}/${line!.runs}',
                  style: TextStyle(
                    color: InningsBreakVisuals.textPrimary,
                    fontSize: cellSize + 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(width: 6 * scale),
                Text(
                  line!.overs,
                  style: TextStyle(
                    color: InningsBreakVisuals.textMuted,
                    fontSize: cellSize - 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({
    required this.text,
    required this.scale,
    required this.landscape,
  });

  final String text;
  final double scale;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(14 * scale, 0, 14 * scale, 12 * scale),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: PostMatchSummaryScreen.resultRed,
          borderRadius: BorderRadius.circular(3 * scale),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 14 * scale,
            vertical: (landscape ? 10 : 9) * scale,
          ),
          child: Text(
            text.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: (landscape ? 16 : 14) * scale,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}
