import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/cf_colors.dart';
import '../providers/series_providers.dart';

/// Chip that marks a match or tournament as belonging to an org: logo (or
/// initial), org name and a verified tick once the org approved it.
///
/// Used by [MatchCardContent] and [TournamentListCard] so org competitions
/// are recognisable wherever they are listed (My Cricket, Home, search…).
class OrgBadge extends ConsumerWidget {
  const OrgBadge({
    super.key,
    required this.seriesId,
    this.pending = false,
    this.onDark = false,
    this.tappable = true,
    this.maxWidth = 220,
  });

  final String seriesId;

  /// Waiting for the org's approval (shown muted, with "Pending").
  final bool pending;

  /// On a photo / dark banner: white text on a translucent chip.
  final bool onDark;

  /// Opens the org page when tapped.
  final bool tappable;
  final double maxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final series = ref.watch(seriesByIdProvider(seriesId)).valueOrNull;
    final name = (series?.name ?? '').trim();
    return OrgBadgeChip(
      name: name.isEmpty ? 'Organization' : name,
      logoUrl: series?.logoUrl,
      pending: pending,
      onDark: onDark,
      maxWidth: maxWidth,
      onTap: tappable ? () => context.push('/series/$seriesId') : null,
    );
  }
}

/// Pure presentation of the org badge (no providers) — also used in tests.
class OrgBadgeChip extends StatelessWidget {
  const OrgBadgeChip({
    super.key,
    required this.name,
    this.logoUrl,
    this.pending = false,
    this.onDark = false,
    this.maxWidth = 220,
    this.onTap,
  });

  final String name;
  final String? logoUrl;
  final bool pending;
  final bool onDark;
  final double maxWidth;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final fg = onDark ? Colors.white : cf.accent;
    final muted = onDark ? Colors.white70 : cf.textSecondary;
    final bg = onDark
        ? Colors.black.withValues(alpha: 0.45)
        : cf.accent.withValues(alpha: cf.isLight ? 0.08 : 0.14);
    final border = onDark
        ? Colors.white.withValues(alpha: 0.35)
        : cf.accent.withValues(alpha: 0.4);
    final hasLogo = (logoUrl ?? '').isNotEmpty;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    final chip = Container(
      key: const Key('org_badge'),
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.fromLTRB(3, 3, 8, 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fg.withValues(alpha: 0.18),
            ),
            alignment: Alignment.center,
            child: hasLogo
                ? CachedNetworkImage(
                    imageUrl: logoUrl!,
                    width: 18,
                    height: 18,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => Text(
                      initial,
                      style: TextStyle(
                        color: fg,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                : Text(
                    initial,
                    style: TextStyle(
                      color: fg,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
            ),
          ),
          const SizedBox(width: 4),
          if (pending)
            Text(
              'Pending',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: muted,
                    fontWeight: FontWeight.w600,
                  ),
            )
          else
            Icon(Icons.verified, size: 13, color: fg),
        ],
      ),
    );

    final tip = pending ? 'Org match · pending approval' : 'Official org match';
    return Tooltip(
      message: tip,
      child: onTap == null
          ? chip
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: chip,
            ),
    );
  }
}
