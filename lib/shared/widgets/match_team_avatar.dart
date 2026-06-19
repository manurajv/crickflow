import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/cf_colors.dart';

/// Circular team logo or initials avatar for match list cards.
class MatchTeamAvatar extends StatelessWidget {
  const MatchTeamAvatar({
    super.key,
    required this.name,
    this.logoUrl,
    this.size = 28,
  });

  final String name;
  final String? logoUrl;
  final double size;

  String get _initials {
    if (name.isEmpty) return '?';
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length == 1) {
      return words[0].substring(0, words[0].length.clamp(0, 2)).toUpperCase();
    }
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final hasImage = logoUrl != null && logoUrl!.isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasImage
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1565C0), CfColors.primaryBlue],
              ),
        color: hasImage ? cf.surfaceElevated : null,
        border: Border.all(
          color: hasImage
              ? cf.border
              : CfColors.primaryBlue.withValues(alpha: 0.45),
          width: 1,
        ),
      ),
      child: ClipOval(
        child: hasImage
            ? CachedNetworkImage(
                imageUrl: logoUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => _Initials(
                  initials: _initials,
                  fontSize: size * 0.34,
                ),
                errorWidget: (_, __, ___) => _Initials(
                  initials: _initials,
                  fontSize: size * 0.34,
                ),
              )
            : _Initials(initials: _initials, fontSize: size * 0.34),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.initials, required this.fontSize});

  final String initials;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: Colors.white,
          fontSize: fontSize,
          height: 1,
        ),
      ),
    );
  }
}
