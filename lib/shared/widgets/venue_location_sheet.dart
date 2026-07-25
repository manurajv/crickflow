import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/cf_colors.dart';
import '../../core/utils/venue_maps_utils.dart';
import '../../data/models/location_model.dart';

/// Opens the shared venue actions sheet (Directions / Ground profile).
///
/// [directionsQuery] or [location] must resolve to a non-empty destination.
/// [groundId] is reserved for a future ground profile route.
Future<void> showVenueLocationSheet(
  BuildContext context, {
  String? title,
  String? directionsQuery,
  LocationModel? location,
  String? groundId,
}) {
  final query = resolveVenueDirectionsQuery(
    directionsQuery: directionsQuery,
    location: location,
  );
  if (query == null) return Future.value();

  final heading = (title ?? location?.placeName ?? query).trim();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final cf = ctx.cf;
      final theme = Theme.of(ctx);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.spaceMd,
            0,
            AppDimens.spaceMd,
            AppDimens.spaceMd,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                heading.isNotEmpty ? heading : 'Location',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (heading != query && query.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  query,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cf.textMuted,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: AppDimens.spaceSm),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.directions_outlined, color: cf.accent),
                title: const Text('Directions'),
                subtitle: Text(
                  'Open in Google Maps',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cf.textMuted,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final ok = await openVenueDirections(
                    destination: query,
                    latitude: location?.latitude,
                    longitude: location?.longitude,
                  );
                  if (!context.mounted) return;
                  if (!ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Could not open Google Maps'),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.stadium_outlined, color: cf.accent),
                title: const Text('Ground profile'),
                subtitle: Text(
                  (groundId?.trim().isNotEmpty ?? false)
                      ? 'View ground details'
                      : 'Coming soon',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cf.textMuted,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ground profile coming soon'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Prefer place label, then free-text query. Coordinates are used only when
/// opening Maps (via [LocationModel] on the sheet).
String? resolveVenueDirectionsQuery({
  String? directionsQuery,
  LocationModel? location,
}) {
  final fromLocation = location?.displayLabel.trim() ?? '';
  if (fromLocation.isNotEmpty) return fromLocation;
  final q = directionsQuery?.trim() ?? '';
  return q.isEmpty ? null : q;
}

/// Compact tappable venue / ground label used on cards and meta rows.
class TappableVenueLocation extends StatelessWidget {
  const TappableVenueLocation({
    super.key,
    required this.label,
    this.directionsQuery,
    this.location,
    this.groundId,
    this.iconSize = 14,
    this.style,
    this.maxLines = 1,
    this.showIcon = true,
    this.underline = true,
  });

  final String label;
  final String? directionsQuery;
  final LocationModel? location;
  final String? groundId;
  final double iconSize;
  final TextStyle? style;
  final int maxLines;
  final bool showIcon;
  final bool underline;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final theme = Theme.of(context);
    final text = label.trim();
    if (text.isEmpty) return const SizedBox.shrink();

    final query = resolveVenueDirectionsQuery(
      directionsQuery: directionsQuery ?? text,
      location: location,
    );
    if (query == null) {
      return Text(
        text,
        style: style ??
            theme.textTheme.bodySmall?.copyWith(color: cf.textSecondary),
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    final resolvedStyle = (style ??
            theme.textTheme.bodySmall?.copyWith(color: cf.textSecondary))
        ?.copyWith(
      color: style?.color ?? cf.accent,
      fontWeight: FontWeight.w600,
      decoration: underline ? TextDecoration.underline : null,
      decorationColor: (style?.color ?? cf.accent).withValues(alpha: 0.55),
    );

    return InkWell(
      onTap: () => showVenueLocationSheet(
        context,
        title: location?.placeName.isNotEmpty == true
            ? location!.placeName
            : text,
        directionsQuery: directionsQuery ?? text,
        location: location,
        groundId: groundId,
      ),
      borderRadius: BorderRadius.circular(4),
      child: Row(
        children: [
          if (showIcon) ...[
            Icon(Icons.location_on_outlined, size: iconSize, color: cf.accent),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              text,
              style: resolvedStyle,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
