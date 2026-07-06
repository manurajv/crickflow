import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../data/models/innings_break_snapshot.dart';
import '../../../../data/models/stream_overlay_theme.dart';
import '../scorebug/scorebug_tokens.dart';
import 'innings_break_side_panels.dart';

/// Formats dismissal for broadcast display (fielder + bowler when present).
String formatInningsBreakDismissal(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  return trimmed.toLowerCase();
}

/// Content-sized broadcast card body (header chrome lives in scorebug host).
class InningsBreakShell extends StatelessWidget {
  const InningsBreakShell({
    super.key,
    required this.snapshot,
    required this.theme,
    required this.landscape,
    required this.child,
    this.teamLogoUrl,
    this.teamName,
    this.subtitle,
    this.footer,
    this.maxBodyHeight,
    this.postMatchLayout = false,
  });

  final InningsBreakSnapshot snapshot;
  final StreamOverlayTheme theme;
  final bool landscape;
  final Widget child;
  final String? teamLogoUrl;
  final String? teamName;
  final String? subtitle;
  final Widget? footer;
  final double? maxBodyHeight;
  final bool postMatchLayout;

  @override
  Widget build(BuildContext context) {
    final tokens = ScorebugTokens.fromTheme(theme);
    final size = MediaQuery.sizeOf(context);
    final scale = postMatchLayout
        ? InningsBreakVisuals.postMatchScaleFor(size.width, landscape)
        : InningsBreakVisuals.scaleFor(size.width, landscape);

    final defaultBodyCap = maxBodyHeight ??
        (landscape ? size.height * 0.72 : size.height * 0.56);
    final headerH = InningsBreakVisuals.headerHeight(scale, landscape);
    final footerH = footer != null
        ? InningsBreakVisuals.scorecardFooterHeight(scale, landscape)
        : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final parentMax = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : defaultBodyCap + headerH + footerH;
        final bodyMax = (parentMax - headerH - footerH)
            .clamp(0.0, defaultBodyCap)
            .toDouble();
        final cardWidth = postMatchLayout
            ? InningsBreakVisuals.postMatchCardMaxWidth(
                landscape: landscape,
                parentMaxWidth: constraints.maxWidth,
                screenWidth: size.width,
                scale: scale,
              )
            : InningsBreakVisuals.cardMaxWidth(
                landscape: landscape,
                parentMaxWidth: constraints.maxWidth,
                screenWidth: size.width,
              );

        return Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: cardWidth,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: InningsBreakVisuals.cardBg,
                borderRadius: BorderRadius.circular(4 * scale),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 18 * scale,
                    offset: Offset(0, 8 * scale),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3 * scale),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ScorecardHeader(
                      snapshot: snapshot,
                      tokens: tokens,
                      scale: scale,
                      landscape: landscape,
                      teamLogoUrl: teamLogoUrl,
                      teamName: teamName,
                      subtitle: subtitle,
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: bodyMax),
                      child: child,
                    ),
                    ?footer,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static double scaleOf(BuildContext context, bool landscape) =>
      InningsBreakVisuals.scaleFor(MediaQuery.sizeOf(context).width, landscape);

  static double postMatchScaleOf(BuildContext context, bool landscape) =>
      InningsBreakVisuals.postMatchScaleFor(
        MediaQuery.sizeOf(context).width,
        landscape,
      );
}

class _ScorecardHeader extends StatelessWidget {
  const _ScorecardHeader({
    required this.snapshot,
    required this.tokens,
    required this.scale,
    required this.landscape,
    this.teamLogoUrl,
    this.teamName,
    this.subtitle,
  });

  final InningsBreakSnapshot snapshot;
  final ScorebugTokens tokens;
  final double scale;
  final bool landscape;
  final String? teamLogoUrl;
  final String? teamName;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final displayTeam = (teamName ?? snapshot.battingTeamName).toUpperCase();
    final displaySubtitle =
        (subtitle ?? snapshot.inningsTitle).toUpperCase();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [InningsBreakVisuals.cardBg, InningsBreakVisuals.headerBg],
        ),
        border: Border(
          bottom: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        12 * scale,
        10 * scale,
        12 * scale,
        8 * scale,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (teamLogoUrl != null && teamLogoUrl!.isNotEmpty)
            Positioned(
              right: 0,
              child: _TeamLogoBox(
                url: teamLogoUrl!,
                size: landscape ? 44 * scale : 36 * scale,
              ),
            ),
          Positioned(
            left: 0,
            child: snapshot.tournamentLogoUrl?.isNotEmpty == true
                ? SizedBox(
                    width: landscape ? 34 * scale : 28 * scale,
                    height: landscape ? 34 * scale : 28 * scale,
                    child: CachedNetworkImage(
                      imageUrl: snapshot.tournamentLogoUrl!,
                      fit: BoxFit.contain,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 52 * scale),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayTeam,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: InningsBreakVisuals.textPrimary,
                    fontSize: (landscape ? 28 : 22) * scale,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    height: 1.05,
                  ),
                ),
                SizedBox(height: 3 * scale),
                Text(
                  displaySubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: InningsBreakVisuals.textMuted,
                    fontSize: (landscape ? 12 : 10.5) * scale,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
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

class _TeamLogoBox extends StatelessWidget {
  const _TeamLogoBox({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: InningsBreakVisuals.cardBg,
        border: Border.all(color: InningsBreakVisuals.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
    );
  }
}

/// Runs + balls display (shared across scorecard, highlights, partnerships).
class InningsBreakRunsBalls extends StatelessWidget {
  const InningsBreakRunsBalls({
    super.key,
    required this.runs,
    required this.balls,
    required this.scale,
    required this.landscape,
    this.inverted = false,
  });

  final int runs;
  final int balls;
  final double scale;
  final bool landscape;
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    final runColor =
        inverted ? Colors.white : InningsBreakVisuals.textPrimary;
    final ballColor = inverted
        ? Colors.white.withValues(alpha: 0.78)
        : InningsBreakVisuals.textMuted;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '$runs',
          style: TextStyle(
            color: runColor,
            fontSize: (landscape ? 24 : 20) * scale,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        SizedBox(width: 5 * scale),
        Text(
          '$balls',
          style: TextStyle(
            color: ballColor,
            fontSize: (landscape ? 13 : 11) * scale,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      ],
    );
  }
}

/// Broadcast scorecard footer — EXTRAS · OVERS · total.
class InningsBreakScorecardFooter extends StatelessWidget {
  const InningsBreakScorecardFooter({
    super.key,
    required this.extras,
    required this.overs,
    required this.totalRuns,
    required this.totalWickets,
    required this.scale,
    this.landscape = true,
  });

  final int extras;
  final String overs;
  final int totalRuns;
  final int totalWickets;
  final double scale;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      color: InningsBreakVisuals.textPrimary,
      fontSize: (landscape ? 13 : 12) * scale,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    );
    final valueStyle = TextStyle(
      color: InningsBreakVisuals.textPrimary,
      fontSize: (landscape ? 13 : 12) * scale,
      fontWeight: FontWeight.w900,
    );
    final totalStyle = TextStyle(
      color: InningsBreakVisuals.textPrimary,
      fontSize: (landscape ? 36 : 30) * scale,
      fontWeight: FontWeight.w900,
      height: 1,
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 18 * scale,
        vertical: (landscape ? 12 : 10) * scale,
      ),
      decoration: BoxDecoration(
        color: InningsBreakVisuals.footerBg,
        border: Border(
          top: BorderSide(color: InningsBreakVisuals.divider),
        ),
      ),
      child: Row(
        children: [
          Text('EXTRAS ', style: labelStyle),
          Text('$extras', style: valueStyle),
          const Spacer(),
          Text('OVERS ', style: labelStyle),
          Text(overs, style: valueStyle),
          SizedBox(width: 12 * scale),
          Text('$totalRuns-$totalWickets', style: totalStyle),
        ],
      ),
    );
  }
}

/// Single batter row — name | fielder(s) | bowler | runs balls.
class InningsBreakBatterRowTile extends StatelessWidget {
  const InningsBreakBatterRowTile({
    super.key,
    required this.name,
    required this.fielderNames,
    required this.bowlerName,
    required this.runs,
    required this.balls,
    required this.isOut,
    required this.scale,
    required this.landscape,
    this.alternate = false,
    this.rowHeight,
  });

  final String name;
  final String fielderNames;
  final String bowlerName;
  final int runs;
  final int balls;
  final bool isOut;
  final double scale;
  final bool landscape;
  final bool alternate;
  final double? rowHeight;

  bool get _notOut => !isOut && (runs > 0 || balls > 0);
  bool get _didNotBat => !isOut && runs == 0 && balls == 0;

  @override
  Widget build(BuildContext context) {
    final rowColor = _notOut
        ? InningsBreakVisuals.highlightBlue
        : (_didNotBat
            ? InningsBreakVisuals.cardBg
            : (alternate
                ? InningsBreakVisuals.rowAlt
                : InningsBreakVisuals.cardBg));

    final nameColor = _notOut
        ? Colors.white
        : (_didNotBat
            ? InningsBreakVisuals.textFaint
            : InningsBreakVisuals.textPrimary);

    final nameSize = (landscape ? 14 : 12) * scale;
    final cellSize = (landscape ? 10.5 : 9.5) * scale;
    final mutedColor = _notOut
        ? Colors.white.withValues(alpha: 0.82)
        : InningsBreakVisuals.textMuted;

    const nameFlex = 5;
    const fielderFlex = 3;
    const bowlerFlex = 2;

    return SizedBox(
      height: rowHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: rowColor,
          border: Border(
            bottom: BorderSide(color: InningsBreakVisuals.divider),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 10 * scale),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: nameFlex,
                child: Text(
                  name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: nameColor,
                    fontSize: nameSize,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              if (_notOut) ...[
                Expanded(flex: fielderFlex, child: SizedBox.shrink()),
                Expanded(
                  flex: bowlerFlex,
                  child: Text(
                    'NOT OUT',
                    textAlign: TextAlign.start,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: cellSize,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ] else if (!_didNotBat) ...[
                Expanded(
                  flex: fielderFlex,
                  child: Text(
                    formatInningsBreakDismissal(fielderNames),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: mutedColor,
                      fontSize: cellSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  flex: bowlerFlex,
                  child: Text(
                    formatInningsBreakDismissal(bowlerName),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.start,
                    style: TextStyle(
                      color: mutedColor,
                      fontSize: cellSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ] else
                Expanded(flex: fielderFlex + bowlerFlex, child: SizedBox.shrink()),
              if (!_didNotBat)
                SizedBox(
                  width: InningsBreakVisuals.batterRunsBallsColumnWidth(
                    landscape,
                    scale,
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: InningsBreakRunsBalls(
                      runs: runs,
                      balls: balls,
                      scale: scale,
                      landscape: landscape,
                      inverted: _notOut,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bowler row — same styling as batting scorecard rows.
class InningsBreakBowlerRowTile extends StatelessWidget {
  const InningsBreakBowlerRowTile({
    super.key,
    required this.name,
    required this.overs,
    required this.maidens,
    required this.runs,
    required this.wickets,
    required this.economy,
    required this.scale,
    required this.landscape,
    this.isBest = false,
    this.alternate = false,
    this.rowHeight,
  });

  final String name;
  final String overs;
  final int maidens;
  final int runs;
  final int wickets;
  final double economy;
  final double scale;
  final bool landscape;
  final bool isBest;
  final bool alternate;
  final double? rowHeight;

  @override
  Widget build(BuildContext context) {
    final rowColor = alternate
        ? InningsBreakVisuals.rowAlt
        : InningsBreakVisuals.cardBg;
    const textColor = InningsBreakVisuals.textPrimary;
    const mutedColor = InningsBreakVisuals.textMuted;
    final nameSize = (landscape ? 15 : 13) * scale;
    final statSize = (landscape ? 14 : 12) * scale;

    return SizedBox(
      height: rowHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: rowColor,
          border: Border(
            bottom: BorderSide(color: InningsBreakVisuals.divider),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14 * scale),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: nameSize,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  overs,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: mutedColor,
                    fontSize: statSize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '$maidens',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: mutedColor,
                    fontSize: statSize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '$runs',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: statSize,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '$wickets',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: statSize,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  economy.toStringAsFixed(2),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: mutedColor,
                    fontSize: statSize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InningsBreakTableHeader extends StatelessWidget {
  const InningsBreakTableHeader({
    super.key,
    required this.scale,
    required this.landscape,
    required this.columns,
    this.columnFlex,
    this.textAlign,
  });

  final double scale;
  final bool landscape;
  final List<String> columns;
  final List<int>? columnFlex;
  final List<TextAlign>? textAlign;

  @override
  Widget build(BuildContext context) {
    final flexes = columnFlex ??
        [for (var i = 0; i < columns.length; i++) i == 0 ? 3 : 1];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 14 * scale,
        vertical: 7 * scale,
      ),
      decoration: BoxDecoration(
        color: InningsBreakVisuals.footerBg,
        border: Border(
          bottom: BorderSide(color: InningsBreakVisuals.divider),
        ),
      ),
      child: Row(
        children: [
          for (var i = 0; i < columns.length; i++)
            Expanded(
              flex: flexes[i],
              child: Text(
                columns[i].toUpperCase(),
                textAlign: textAlign != null
                    ? textAlign![i]
                    : (i == 0 ? TextAlign.start : TextAlign.center),
                style: TextStyle(
                  color: InningsBreakVisuals.textMuted,
                  fontSize: (landscape ? 10 : 9) * scale,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Fall-of-wickets row aligned to [InningsBreakVisuals.fallOfWicketsColumnFlex].
class InningsBreakFallOfWicketRowTile extends StatelessWidget {
  const InningsBreakFallOfWicketRowTile({
    super.key,
    required this.wicketNumber,
    required this.score,
    required this.over,
    required this.batterName,
    required this.fielderNames,
    required this.bowlerName,
    required this.scale,
    required this.landscape,
    this.alternate = false,
    this.rowHeight,
  });

  final int wicketNumber;
  final int score;
  final String over;
  final String batterName;
  final String fielderNames;
  final String bowlerName;
  final double scale;
  final bool landscape;
  final bool alternate;
  final double? rowHeight;

  static const _flex = InningsBreakVisuals.fallOfWicketsColumnFlex;

  @override
  Widget build(BuildContext context) {
    final cellSize = (landscape ? 10.5 : 9.5) * scale;
    final primaryStyle = TextStyle(
      color: InningsBreakVisuals.textPrimary,
      fontSize: cellSize,
      fontWeight: FontWeight.w700,
    );
    final mutedStyle = TextStyle(
      color: InningsBreakVisuals.textMuted,
      fontSize: cellSize,
      fontWeight: FontWeight.w600,
    );

    return SizedBox(
      height: rowHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: alternate ? InningsBreakVisuals.rowAlt : InningsBreakVisuals.cardBg,
          border: Border(
            bottom: BorderSide(color: InningsBreakVisuals.divider),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14 * scale),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: _flex[0],
                child: Text(
                  '$wicketNumber',
                  textAlign: TextAlign.center,
                  style: primaryStyle,
                ),
              ),
              Expanded(
                flex: _flex[1],
                child: Text(
                  '$score',
                  textAlign: TextAlign.center,
                  style: primaryStyle,
                ),
              ),
              Expanded(
                flex: _flex[2],
                child: Text(
                  over,
                  textAlign: TextAlign.center,
                  style: primaryStyle,
                ),
              ),
              Expanded(
                flex: _flex[3],
                child: Text(
                  batterName.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.start,
                  style: primaryStyle,
                ),
              ),
              Expanded(
                flex: _flex[4],
                child: Text(
                  formatInningsBreakDismissal(fielderNames),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: mutedStyle,
                ),
              ),
              Expanded(
                flex: _flex[5],
                child: Text(
                  formatInningsBreakDismissal(bowlerName),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: mutedStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InningsBreakHighlightAvatar extends StatelessWidget {
  const InningsBreakHighlightAvatar({
    super.key,
    required this.name,
    required this.photoUrl,
    required this.tokens,
    required this.scale,
  });

  final String name;
  final String? photoUrl;
  final ScorebugTokens tokens;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(' ').take(2).map((w) => w[0]).join().toUpperCase();

    return Container(
      width: 44 * scale,
      height: 44 * scale,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6 * scale),
        border: Border.all(
          color: InningsBreakVisuals.divider,
          width: 1 * scale,
        ),
        color: InningsBreakVisuals.rowAlt,
      ),
      clipBehavior: Clip.antiAlias,
      child: photoUrl != null && photoUrl!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: photoUrl!,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            )
          : Center(
              child: Text(
                initials,
                style: TextStyle(
                  color: InningsBreakVisuals.textMuted,
                  fontWeight: FontWeight.w900,
                  fontSize: 14 * scale,
                ),
              ),
            ),
    );
  }
}

class InningsBreakEmptyNote extends StatelessWidget {
  const InningsBreakEmptyNote({
    super.key,
    required this.message,
    required this.scale,
    this.landscape = true,
  });

  final String message;
  final double scale;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(20 * scale),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: InningsBreakVisuals.textMuted,
          fontSize: (landscape ? 13 : 12) * scale,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class InningsBreakPanel extends StatelessWidget {
  const InningsBreakPanel({
    super.key,
    required this.scale,
    required this.child,
    this.padding,
  });

  final double scale;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? EdgeInsets.all(12 * scale),
      child: child,
    );
  }
}
