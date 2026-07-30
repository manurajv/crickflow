import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';
import '../../core/theme/admin_colors.dart';

/// Lazy network image with progressive placeholder — never blocks list scroll.
///
/// On Flutter web, prefers HTML `<img>` rendering so Firebase Storage download
/// URLs display even when the bucket CORS policy does not allow byte fetch
/// (CanvasKit `NetworkImage` otherwise fails with statusCode 0).
class CfNetworkImage extends StatelessWidget {
  const CfNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.semanticLabel,
  });

  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final dimens = context.adminDimens;
    final radius = borderRadius ?? dimens.borderRadiusMd;
    final placeholder = ColoredBox(
      color: colors.background,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          color: colors.textMuted,
          size: dimens.iconLg,
        ),
      ),
    );

    final trimmed = url?.trim() ?? '';
    if (trimmed.isEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: SizedBox(width: width, height: height, child: placeholder),
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        trimmed,
        width: width,
        height: height,
        fit: fit,
        semanticLabel: semanticLabel,
        filterQuality: FilterQuality.medium,
        // Avoid CORS byte-fetch failures on web (Firebase Storage).
        webHtmlElementStrategy: kIsWeb
            ? WebHtmlElementStrategy.prefer
            : WebHtmlElementStrategy.never,
        cacheWidth: width != null && width!.isFinite
            ? (width! * MediaQuery.devicePixelRatioOf(context)).round()
            : null,
        cacheHeight: height != null && height!.isFinite
            ? (height! * MediaQuery.devicePixelRatioOf(context)).round()
            : null,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) return child;
          return SizedBox(width: width, height: height, child: placeholder);
        },
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            width: width,
            height: height,
            child: ColoredBox(
              color: colors.background,
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AdminColors.primaryBlue,
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded /
                            progress.expectedTotalBytes!
                        : null,
                  ),
                ),
              ),
            ),
          );
        },
        errorBuilder: (_, _, _) =>
            SizedBox(width: width, height: height, child: placeholder),
      ),
    );
  }
}

/// Circular avatar that never throws [NetworkImageLoadException] into the zone.
class CfAvatar extends StatelessWidget {
  const CfAvatar({
    super.key,
    this.url,
    this.radius = 20,
    this.label,
  });

  final String? url;
  final double radius;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final size = radius * 2;
    final initial = (label ?? '?').trim();
    final letter = initial.isEmpty
        ? '?'
        : String.fromCharCode(initial.runes.first).toUpperCase();

    final trimmed = url?.trim() ?? '';
    if (trimmed.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: colors.background,
        child: Text(letter, style: TextStyle(fontSize: radius * 0.7)),
      );
    }

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: colors.background,
              child: Center(
                child: Text(letter, style: TextStyle(fontSize: radius * 0.7)),
              ),
            ),
            CfNetworkImage(
              url: trimmed,
              width: size,
              height: size,
              borderRadius: BorderRadius.zero,
            ),
          ],
        ),
      ),
    );
  }
}
