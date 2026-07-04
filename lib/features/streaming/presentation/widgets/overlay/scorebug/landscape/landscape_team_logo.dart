import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../scorebug_tokens.dart';

/// Square team crest for the broadcast scorebug.
class LandscapeTeamLogo extends StatelessWidget {
  const LandscapeTeamLogo({
    super.key,
    required this.name,
    this.logoUrl,
    required this.size,
    required this.tokens,
  });

  final String name;
  final String? logoUrl;
  final double size;
  final ScorebugTokens tokens;

  String get _initials {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final words = trimmed.split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return words.take(2).map((w) => w[0].toUpperCase()).join();
    }
    return trimmed.substring(0, trimmed.length.clamp(0, 2)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = logoUrl != null && logoUrl!.isNotEmpty;
    return SizedBox(
      width: size,
      height: size,
      child: ColoredBox(
        color: tokens.white,
        child: hasImage
            ? CachedNetworkImage(
                imageUrl: logoUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => _Initials(initials: _initials, size: size),
                errorWidget: (_, __, ___) =>
                    _Initials(initials: _initials, size: size),
              )
            : _Initials(initials: _initials, size: size),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.initials, required this.size});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          color: const Color(0xFF0A1628),
          fontWeight: FontWeight.w900,
          fontSize: size * 0.32,
          height: 1,
        ),
      ),
    );
  }
}
