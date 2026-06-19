import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/cf_colors.dart';

/// Circular avatar for lineup / innings player pickers.
class LineupPlayerAvatar extends StatelessWidget {
  const LineupPlayerAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.radius = 24,
    this.backgroundColor,
    this.foregroundColor,
    this.fontSize,
  });

  final String name;
  final String? photoUrl;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    final initial = name.isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    final bg = backgroundColor ?? cf.sectionBackground;
    final fg = foregroundColor ?? cf.accent;
    final textSize = fontSize ?? radius * 0.75;

    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      backgroundImage: hasPhoto
          ? CachedNetworkImageProvider(photoUrl!)
          : null,
      child: hasPhoto
          ? null
          : Text(
              initial,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: textSize,
                color: fg,
              ),
            ),
    );
  }
}
