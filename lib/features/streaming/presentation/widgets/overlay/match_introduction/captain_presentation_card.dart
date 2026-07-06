import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../data/models/match_introduction_snapshot.dart';
import '../scorebug/landscape/landscape_team_logo.dart';
import '../scorebug/scorebug_tokens.dart';

/// Captain photo, team logo, and full team name for one side of the intro.
class CaptainPresentationCard extends StatelessWidget {
  const CaptainPresentationCard({
    super.key,
    required this.side,
    required this.tokens,
    required this.scale,
    required this.opacity,
    required this.slideOffset,
    this.mirror = false,
    this.photoOnly = false,
    this.photoHeight,
    this.photoWidth,
  });

  final MatchIntroductionTeamSide side;
  final ScorebugTokens tokens;
  final double scale;
  final double opacity;
  final Offset slideOffset;
  final bool mirror;
  final bool photoOnly;
  final double? photoHeight;
  final double? photoWidth;

  @override
  Widget build(BuildContext context) {
    final logoSize = 54 * scale;
    final resolvedPhotoHeight = photoHeight ?? 280 * scale;
    final resolvedPhotoWidth = photoWidth ?? 210 * scale;

    final photo = _CaptainPhotoFrame(
      side: side,
      tokens: tokens,
      scale: scale,
      height: resolvedPhotoHeight,
      width: resolvedPhotoWidth,
      mirror: mirror,
    );

    if (photoOnly) {
      return Opacity(
        opacity: opacity,
        child: Transform.translate(
          offset: slideOffset,
          child: _CaptainPhotoWithBackdrop(
            side: side,
            tokens: tokens,
            scale: scale,
            height: resolvedPhotoHeight,
            width: resolvedPhotoWidth,
            mirror: mirror,
          ),
        ),
      );
    }

    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: slideOffset,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            photo,
            SizedBox(height: 14 * scale),
            LandscapeTeamLogo(
              name: side.teamName,
              logoUrl: side.teamLogoUrl,
              size: logoSize,
              tokens: tokens,
            ),
            SizedBox(height: 10 * scale),
            Container(
              constraints: BoxConstraints(maxWidth: 260 * scale),
              padding: EdgeInsets.symmetric(
                horizontal: 14 * scale,
                vertical: 8 * scale,
              ),
              decoration: BoxDecoration(
                color: tokens.panelBg.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(10 * scale),
                border: Border(
                  top: BorderSide(color: tokens.gold, width: 2 * scale),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 14 * scale,
                    offset: Offset(0, 6 * scale),
                  ),
                ],
              ),
              child: Text(
                side.teamName.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tokens.white,
                  fontSize: 16 * scale,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  height: 1.15,
                ),
              ),
            ),
            if (side.captainName != null && side.captainName!.isNotEmpty) ...[
              SizedBox(height: 6 * scale),
              Text(
                side.captainName!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: tokens.white.withValues(alpha: 0.88),
                  fontSize: 12 * scale,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                'CAPTAIN',
                style: TextStyle(
                  color: tokens.gold.withValues(alpha: 0.95),
                  fontSize: 10 * scale,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Side-by-side captain photos with spacing and accent backdrop.
class CaptainsFaceOffRow extends StatelessWidget {
  const CaptainsFaceOffRow({
    super.key,
    required this.snapshot,
    required this.tokens,
    required this.scale,
    required this.photoHeight,
    required this.photoWidth,
    required this.photoGap,
    required this.opacity,
    required this.leftSlide,
    required this.rightSlide,
  });

  final MatchIntroductionSnapshot snapshot;
  final ScorebugTokens tokens;
  final double scale;
  final double photoHeight;
  final double photoWidth;
  final double photoGap;
  final double opacity;
  final Offset leftSlide;
  final Offset rightSlide;

  @override
  Widget build(BuildContext context) {
    final stageWidth = photoWidth * 2 + photoGap + 48 * scale;
    final stageHeight = photoHeight + 56 * scale;

    return SizedBox(
      width: stageWidth,
      height: stageHeight,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          _OverlappingLightBox(
            tokens: tokens,
            scale: scale,
            width: stageWidth * 0.84,
            height: photoHeight * 0.74,
            top: 22 * scale,
            left: 6 * scale,
            gradient: [
              snapshot.teamA.accentColor.withValues(alpha: 0.22),
              tokens.panelBg.withValues(alpha: 0.08),
            ],
            borderColor: snapshot.teamA.accentColor.withValues(alpha: 0.35),
          ),
          _OverlappingLightBox(
            tokens: tokens,
            scale: scale,
            width: stageWidth * 0.78,
            height: photoHeight * 0.7,
            top: 36 * scale,
            left: stageWidth * 0.12,
            gradient: [
              tokens.gold.withValues(alpha: 0.16),
              tokens.white.withValues(alpha: 0.06),
            ],
            borderColor: tokens.gold.withValues(alpha: 0.32),
          ),
          _OverlappingLightBox(
            tokens: tokens,
            scale: scale,
            width: stageWidth * 0.72,
            height: photoHeight * 0.64,
            top: 10 * scale,
            left: stageWidth * 0.06,
            gradient: [
              snapshot.teamB.accentColor.withValues(alpha: 0.18),
              Colors.transparent,
            ],
            borderColor: snapshot.teamB.accentColor.withValues(alpha: 0.28),
          ),
          Positioned(
            bottom: 4 * scale,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                CaptainPresentationCard(
                  side: snapshot.teamA,
                  tokens: tokens,
                  scale: scale,
                  opacity: opacity,
                  slideOffset: leftSlide,
                  photoOnly: true,
                  photoHeight: photoHeight,
                  photoWidth: photoWidth,
                ),
                SizedBox(width: photoGap),
                CaptainPresentationCard(
                  side: snapshot.teamB,
                  tokens: tokens,
                  scale: scale,
                  opacity: opacity,
                  slideOffset: rightSlide,
                  mirror: true,
                  photoOnly: true,
                  photoHeight: photoHeight,
                  photoWidth: photoWidth,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlappingLightBox extends StatelessWidget {
  const _OverlappingLightBox({
    required this.tokens,
    required this.scale,
    required this.width,
    required this.height,
    required this.top,
    required this.left,
    required this.gradient,
    required this.borderColor,
  });

  final ScorebugTokens tokens;
  final double scale;
  final double width;
  final double height;
  final double top;
  final double left;
  final List<Color> gradient;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(18 * scale),
          border: Border.all(color: borderColor, width: 1 * scale),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 18 * scale,
              offset: Offset(0, 8 * scale),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptainPhotoWithBackdrop extends StatelessWidget {
  const _CaptainPhotoWithBackdrop({
    required this.side,
    required this.tokens,
    required this.scale,
    required this.height,
    required this.width,
    required this.mirror,
  });

  final MatchIntroductionTeamSide side;
  final ScorebugTokens tokens;
  final double scale;
  final double height;
  final double width;
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    final padH = 14 * scale;
    final padBottom = 10 * scale;
    final lift = 12 * scale;

    return SizedBox(
      width: width + padH * 2,
      height: height + padBottom + lift,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            left: mirror ? 10 * scale : -6 * scale,
            bottom: padBottom + 6 * scale,
            child: _OverlappingCaptainBox(
              width: width + 22 * scale,
              height: height * 0.55,
              scale: scale,
              gradient: [
                side.accentColor.withValues(alpha: 0.24),
                side.accentColor.withValues(alpha: 0.06),
              ],
              borderColor: side.accentColor.withValues(alpha: 0.38),
            ),
          ),
          Positioned(
            right: mirror ? -4 * scale : 8 * scale,
            bottom: padBottom + 18 * scale,
            child: _OverlappingCaptainBox(
              width: width + 16 * scale,
              height: height * 0.48,
              scale: scale,
              gradient: [
                tokens.gold.withValues(alpha: 0.14),
                tokens.white.withValues(alpha: 0.04),
              ],
              borderColor: tokens.gold.withValues(alpha: 0.34),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: padBottom,
            child: _OverlappingCaptainBox(
              width: width + padH * 2,
              height: height + 8 * scale,
              scale: scale,
              gradient: [
                tokens.panelBg.withValues(alpha: 0.16),
                tokens.white.withValues(alpha: 0.05),
                Colors.transparent,
              ],
              borderColor: tokens.white.withValues(alpha: 0.32),
            ),
          ),
          Positioned(
            bottom: padBottom + lift,
            child: _CaptainPhotoFrame(
              side: side,
              tokens: tokens,
              scale: scale,
              height: height,
              width: width,
              mirror: mirror,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlappingCaptainBox extends StatelessWidget {
  const _OverlappingCaptainBox({
    required this.width,
    required this.height,
    required this.scale,
    required this.gradient,
    required this.borderColor,
  });

  final double width;
  final double height;
  final double scale;
  final List<Color> gradient;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(18 * scale),
        border: Border.all(color: borderColor, width: 1 * scale),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12 * scale,
            offset: Offset(0, 5 * scale),
          ),
        ],
      ),
    );
  }
}

class _CaptainPhotoFrame extends StatelessWidget {
  const _CaptainPhotoFrame({
    required this.side,
    required this.tokens,
    required this.scale,
    required this.height,
    required this.width,
    required this.mirror,
  });

  final MatchIntroductionTeamSide side;
  final ScorebugTokens tokens;
  final double scale;
  final double height;
  final double width;
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    final radius = 16 * scale;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: tokens.navyDeep,
        border: Border.all(
          color: tokens.white.withValues(alpha: 0.88),
          width: 2 * scale,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.72),
            blurRadius: 28 * scale,
            spreadRadius: 2 * scale,
            offset: Offset(0, 12 * scale),
          ),
          BoxShadow(
            color: side.accentColor.withValues(alpha: 0.35),
            blurRadius: 18 * scale,
            offset: Offset(mirror ? -4 * scale : 4 * scale, 0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 2 * scale),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: tokens.navyDeep),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: mirror ? Alignment.centerRight : Alignment.centerLeft,
                  end: mirror ? Alignment.centerLeft : Alignment.centerRight,
                  colors: [
                    side.accentColor.withValues(alpha: 0.28),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.45],
                ),
              ),
            ),
            if (side.hasCaptainPhoto)
              CachedNetworkImage(
                imageUrl: side.captainPhotoUrl!,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                placeholder: (_, __) => _Silhouette(
                  side: side,
                  tokens: tokens,
                  scale: scale,
                  height: height,
                ),
                errorWidget: (_, __, ___) => _Silhouette(
                  side: side,
                  tokens: tokens,
                  scale: scale,
                  height: height,
                ),
              )
            else
              _Silhouette(
                side: side,
                tokens: tokens,
                scale: scale,
                height: height,
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.12),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.42),
                  ],
                  stops: const [0, 0.55, 1],
                ),
              ),
            ),
            Positioned(
              left: mirror ? null : 0,
              right: mirror ? 0 : null,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4 * scale,
                color: side.accentColor.withValues(alpha: 0.95),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 3 * scale,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      tokens.gold.withValues(alpha: 0.2),
                      tokens.gold,
                      tokens.gold.withValues(alpha: 0.2),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Silhouette extends StatelessWidget {
  const _Silhouette({
    required this.side,
    required this.tokens,
    required this.scale,
    required this.height,
  });

  final MatchIntroductionTeamSide side;
  final ScorebugTokens tokens;
  final double scale;
  final double height;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(tokens.panelBg, side.accentColor, 0.35)!,
            tokens.navyDeep.withValues(alpha: 0.92),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          size: math.max(48 * scale, height * 0.32),
          color: tokens.white.withValues(alpha: 0.42),
        ),
      ),
    );
  }
}
