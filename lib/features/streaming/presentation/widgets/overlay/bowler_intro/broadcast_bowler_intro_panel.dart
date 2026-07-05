import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/bowler_intro_profile.dart';
import '../../../../data/models/stream_overlay_theme.dart';
import '../../../providers/player_intro_lookup.dart';
import '../../../providers/streaming_studio_providers.dart';
import '../events/broadcast_event_anim.dart';
import '../scorebug/landscape/landscape_scorebug_layout.dart';
import '../scorebug/landscape/landscape_team_logo.dart';
import '../scorebug/scorebug_tokens.dart';

/// TV-style bowler career card — slides in from the side for ~5 seconds.
class BroadcastBowlerIntroPanel extends ConsumerStatefulWidget {
  const BroadcastBowlerIntroPanel({
    super.key,
    required this.matchId,
    required this.event,
    required this.tokens,
    required this.landscape,
    required this.scale,
    this.maxHeight,
    this.onFinished,
    this.forBurnInCapture = false,
  });

  final String matchId;
  final StreamEventOverlay event;
  final ScorebugTokens tokens;
  final bool landscape;
  final double scale;
  final double? maxHeight;
  final VoidCallback? onFinished;
  final bool forBurnInCapture;

  @override
  ConsumerState<BroadcastBowlerIntroPanel> createState() =>
      _BroadcastBowlerIntroPanelState();
}

class _BroadcastBowlerIntroPanelState
    extends ConsumerState<BroadcastBowlerIntroPanel>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<Offset>? _slide;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    final controller = AnimationController(
      vsync: this,
      duration: BroadcastEventAnim.defaultEnter,
      reverseDuration: BroadcastEventAnim.defaultExit,
    );
    _controller = controller;
    _slide = Tween<Offset>(
      begin: Offset(widget.landscape ? 1.08 : 1.05, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOutCubic));

    unawaited(
      BroadcastEventAnim.runSequence(
        controller: controller,
        hold: widget.event.duration,
        isMounted: () => mounted,
        onFinished: _finish,
      ),
    );
  }

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    widget.onFinished?.call();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lookup = PlayerIntroLookup(
      matchId: widget.matchId,
      playerId: widget.event.playerId,
      fallbackName: widget.event.playerName,
    );
    final profileAsync = ref.watch(bowlerIntroProfileProvider(lookup));
    final profile = profileAsync.valueOrNull ??
        BowlerIntroProfile(playerName: widget.event.playerName);

    final card = widget.landscape
        ? _LandscapeBowlerIntroCard(
            profile: profile,
            tokens: widget.tokens,
            scale: widget.scale,
            maxHeight: widget.maxHeight,
          )
        : _PortraitBowlerIntroCard(
            profile: profile,
            tokens: widget.tokens,
            scale: widget.scale,
          );

    if (_controller == null) {
      return card;
    }

    return AnimatedBuilder(
      animation: _controller!,
      builder: (context, child) {
        return Opacity(
          opacity: BroadcastEventAnim.exitAwareOpacity(_controller!),
          child: SlideTransition(
            position: _slide!,
            child: child,
          ),
        );
      },
      child: card,
    );
  }
}

/// Broadcast-style vertical player card for landscape streams.
class _LandscapeBowlerIntroCard extends StatelessWidget {
  const _LandscapeBowlerIntroCard({
    required this.profile,
    required this.tokens,
    required this.scale,
    this.maxHeight,
  });

  final BowlerIntroProfile profile;
  final ScorebugTokens tokens;
  final double scale;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final width = 248 * scale;
    final logoSize = 34 * scale;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        height: maxHeight,
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 22 * scale,
              offset: Offset(-6 * scale, 6 * scale),
            ),
          ],
        ),
        child: ClipRect(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(tokens.navyDeep, tokens.panelBg, 0.35)!,
                  tokens.navyDeep,
                ],
              ),
              border: Border(
                left: BorderSide(color: tokens.gold, width: 3 * scale),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeaderBand(
                  profile: profile,
                  tokens: tokens,
                  scale: scale,
                  logoSize: logoSize,
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      10 * scale,
                      8 * scale,
                      10 * scale,
                      8 * scale,
                    ),
                    child: _PlayerHero(
                      profile: profile,
                      tokens: tokens,
                      scale: scale,
                    ),
                  ),
                ),
                _StatsPanel(
                  profile: profile,
                  tokens: tokens,
                  scale: scale,
                  compact: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderBand extends StatelessWidget {
  const _HeaderBand({
    required this.profile,
    required this.tokens,
    required this.scale,
    required this.logoSize,
  });

  final BowlerIntroProfile profile;
  final ScorebugTokens tokens;
  final double scale;
  final double logoSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 7 * scale),
      color: tokens.panelBg.withValues(alpha: 0.96),
      child: Row(
        children: [
          LandscapeTeamLogo(
            name: profile.teamName.isNotEmpty ? profile.teamName : 'Team',
            logoUrl: profile.teamLogoUrl,
            size: logoSize,
            tokens: tokens,
          ),
          SizedBox(width: 8 * scale),
          Expanded(
            child: Text(
              (profile.teamName.isNotEmpty ? profile.teamName : 'Team')
                  .toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tokens.white,
                fontSize: 10 * scale,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                height: 1.1,
              ),
            ),
          ),
          if (profile.formatLabel.isNotEmpty) ...[
            SizedBox(width: 6 * scale),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 8 * scale,
                vertical: 4 * scale,
              ),
              decoration: BoxDecoration(
                color: tokens.gold,
                border: Border.all(
                  color: tokens.white.withValues(alpha: 0.45),
                  width: 1,
                ),
              ),
              child: Text(
                profile.formatLabel.toUpperCase(),
                style: TextStyle(
                  color: tokens.onScore,
                  fontSize: 9 * scale,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  height: 1,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Full-bleed player photo with name and bowling style overlaid at the bottom.
class _PlayerHero extends StatelessWidget {
  const _PlayerHero({
    required this.profile,
    required this.tokens,
    required this.scale,
  });

  final BowlerIntroProfile profile;
  final ScorebugTokens tokens;
  final double scale;

  static const _textShadows = [
    Shadow(color: Colors.black, blurRadius: 6, offset: Offset(0, 1)),
    Shadow(color: Colors.black87, blurRadius: 12, offset: Offset(0, 2)),
  ];

  @override
  Widget build(BuildContext context) {
    final initials = _initials(profile.playerName);
    final hasPhoto = profile.photoUrl != null && profile.photoUrl!.isNotEmpty;
    final nameSize = 13 * scale;
    final styleSize = 9 * scale;

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: const Color(0xFF0A1628),
              child: hasPhoto
                  ? CachedNetworkImage(
                      imageUrl: profile.photoUrl!,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      placeholder: (_, a) =>
                          _InitialsBackdrop(initials: initials, tokens: tokens),
                      errorWidget: (_, a, b) =>
                          _InitialsBackdrop(initials: initials, tokens: tokens),
                    )
                  : _InitialsBackdrop(initials: initials, tokens: tokens),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 72 * scale,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.55),
                    Colors.black.withValues(alpha: 0.92),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            left: 8 * scale,
            right: 8 * scale,
            bottom: 8 * scale,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _LegibleOverlayText(
                  text: profile.playerName.toUpperCase(),
                  fontSize: nameSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  maxLines: 2,
                ),
                if (profile.bowlingStyle.trim().isNotEmpty) ...[
                  SizedBox(height: 3 * scale),
                  _LegibleOverlayText(
                    text: profile.bowlingStyle.toUpperCase(),
                    fontSize: styleSize,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    maxLines: 1,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final words = trimmed.split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return words.take(2).map((w) => w[0].toUpperCase()).join();
    }
    return trimmed.substring(0, trimmed.length.clamp(0, 2)).toUpperCase();
  }
}

/// White text with dark stroke + shadow so it reads on any photo.
class _LegibleOverlayText extends StatelessWidget {
  const _LegibleOverlayText({
    required this.text,
    required this.fontSize,
    required this.fontWeight,
    this.letterSpacing = 0,
    this.maxLines = 1,
  });

  final String text;
  final double fontSize;
  final FontWeight fontWeight;
  final double letterSpacing;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    const fill = Colors.white;
    const stroke = Colors.black;

    return Stack(
      children: [
        Text(
          text,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.left,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            letterSpacing: letterSpacing,
            height: 1.05,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = fontSize * 0.14
              ..color = stroke,
          ),
        ),
        Text(
          text,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.left,
          style: TextStyle(
            color: fill,
            fontSize: fontSize,
            fontWeight: fontWeight,
            letterSpacing: letterSpacing,
            height: 1.05,
            shadows: _PlayerHero._textShadows,
          ),
        ),
      ],
    );
  }
}

class _InitialsBackdrop extends StatelessWidget {
  const _InitialsBackdrop({
    required this.initials,
    required this.tokens,
  });

  final String initials;
  final ScorebugTokens tokens;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tokens.panelBg,
            tokens.navyDeep,
          ],
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: tokens.white.withValues(alpha: 0.35),
            fontWeight: FontWeight.w900,
            fontSize: 48,
          ),
        ),
      ),
    );
  }
}

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({
    required this.profile,
    required this.tokens,
    required this.scale,
    this.compact = false,
  });

  final BowlerIntroProfile profile;
  final ScorebugTokens tokens;
  final double scale;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final padV = compact ? 6 * scale : 8 * scale;
    final gap = compact ? 4 * scale : 6 * scale;
    final cellPadV = compact ? 3 * scale : 5 * scale;

    return Container(
      color: tokens.white.withValues(alpha: 0.97),
      padding: EdgeInsets.fromLTRB(10 * scale, padV, 10 * scale, padV),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'CAREER STATS',
            style: LandscapeScorebugLayout.labelStyle(tokens, scale).copyWith(
              fontSize: 9 * scale,
              letterSpacing: 1.1,
            ),
          ),
          SizedBox(height: gap),
          Row(
            children: [
              Expanded(
                child: _StatCell(
                  label: 'MAT',
                  value: _formatCount(profile.matches),
                  tokens: tokens,
                  scale: scale,
                  padV: cellPadV,
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                child: _StatCell(
                  label: 'WKTS',
                  value: _formatCount(profile.wickets),
                  tokens: tokens,
                  scale: scale,
                  padV: cellPadV,
                ),
              ),
            ],
          ),
          SizedBox(height: gap),
          Row(
            children: [
              Expanded(
                child: _StatCell(
                  label: 'AVG',
                  value: _formatAverage(profile.average),
                  tokens: tokens,
                  scale: scale,
                  padV: cellPadV,
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                child: _StatCell(
                  label: '5WI',
                  value: _formatCount(profile.fiveWicketHauls),
                  tokens: tokens,
                  scale: scale,
                  padV: cellPadV,
                ),
              ),
            ],
          ),
          SizedBox(height: gap),
          _StatCell(
            label: 'BEST',
            value: profile.bestFigures,
            tokens: tokens,
            scale: scale,
            padV: cellPadV,
            wide: true,
          ),
        ],
      ),
    );
  }

  static String _formatAverage(double average) {
    if (average <= 0) return '—';
    return average.toStringAsFixed(1);
  }

  static String _formatCount(int value) {
    if (value <= 0) return '—';
    return '$value';
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    required this.tokens,
    required this.scale,
    required this.padV,
    this.wide = false,
  });

  final String label;
  final String value;
  final ScorebugTokens tokens;
  final double scale;
  final double padV;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: wide ? double.infinity : null,
      padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: padV),
      decoration: BoxDecoration(
        color: tokens.onScore.withValues(alpha: 0.04),
        border: Border(
          left: BorderSide(color: tokens.blue, width: 2 * scale),
        ),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: LandscapeScorebugLayout.labelStyle(tokens, scale).copyWith(
              fontSize: 8 * scale,
              color: tokens.onScore.withValues(alpha: 0.65),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: LandscapeScorebugLayout.valueStyle(tokens, scale).copyWith(
              fontSize: wide ? 13 * scale : 12 * scale,
            ),
          ),
        ],
      ),
    );
  }
}

class _PortraitBowlerIntroCard extends StatelessWidget {
  const _PortraitBowlerIntroCard({
    required this.profile,
    required this.tokens,
    required this.scale,
  });

  final BowlerIntroProfile profile;
  final ScorebugTokens tokens;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final width = 168 * scale;
    final logoSize = 32 * scale;
    final heroHeight = 112 * scale;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(tokens.navyDeep, tokens.panelBg, 0.35)!,
              tokens.navyDeep,
            ],
          ),
          border: Border(left: BorderSide(color: tokens.gold, width: 3 * scale)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 16 * scale,
              offset: Offset(-4 * scale, 4 * scale),
            ),
          ],
        ),
        child: ClipRect(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeaderBand(
                profile: profile,
                tokens: tokens,
                scale: scale,
                logoSize: logoSize,
              ),
              SizedBox(
                height: heroHeight,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(8 * scale, 8 * scale, 8 * scale, 6 * scale),
                  child: _PlayerHero(
                    profile: profile,
                    tokens: tokens,
                    scale: scale,
                  ),
                ),
              ),
              _StatsPanel(
                profile: profile,
                tokens: tokens,
                scale: scale,
                compact: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
