import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../../../shared/widgets/cf_empty_state.dart';
import '../../models/managed_ground.dart';

/// Lightweight map-ready list (Google Maps SDK clustering is future-ready).
class GroundsMapPreview extends StatelessWidget {
  const GroundsMapPreview({
    super.key,
    required this.grounds,
    required this.selectedId,
    required this.onSelect,
  });

  final List<ManagedGround> grounds;
  final String? selectedId;
  final ValueChanged<ManagedGround> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final withCoords = grounds.where((g) => g.hasCoordinates).toList();
    final withoutCoords = grounds.where((g) => !g.hasCoordinates).toList();

    if (grounds.isEmpty) {
      return const CfCard(
        child: SizedBox(
          height: 240,
          child: CfEmptyState(
            icon: Icons.map_outlined,
            title: 'No grounds to map',
            message: 'Add grounds with coordinates to enable map view.',
          ),
        ),
      );
    }

    return CfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.map_outlined, color: colors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Map view',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              Text(
                '${withCoords.length} with coordinates',
                style: TextStyle(color: colors.textMuted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Interactive map clustering is future-ready. Open any pin in Google Maps, or select a ground for details.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
          ),
          const SizedBox(height: 16),
          if (withCoords.isEmpty)
            Text(
              'No grounds in this page have latitude/longitude yet.',
              style: TextStyle(color: colors.textMuted),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final g in withCoords)
                  _MapPinCard(
                    ground: g,
                    selected: g.id == selectedId,
                    onTap: () => onSelect(g),
                  ),
              ],
            ),
          if (withoutCoords.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Without coordinates (${withoutCoords.length})',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            ...withoutCoords.take(12).map(
                  (g) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.place_outlined),
                    title: Text(g.name),
                    subtitle: Text(g.locationLabel),
                    onTap: () => onSelect(g),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _MapPinCard extends StatelessWidget {
  const _MapPinCard({
    required this.ground,
    required this.selected,
    required this.onTap,
  });

  final ManagedGround ground;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AdminColors.primaryBlue : colors.border,
            width: selected ? 2 : 1,
          ),
          color: selected
              ? AdminColors.primaryBlue.withValues(alpha: 0.06)
              : colors.background,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: AdminColors.primaryBlue,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    ground.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              ground.locationLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              '${ground.latitude!.toStringAsFixed(4)}, ${ground.longitude!.toStringAsFixed(4)}',
              style: TextStyle(color: colors.textSecondary, fontSize: 11),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(ground.mapsUrl),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new, size: 14),
              label: const Text('Open in Maps'),
            ),
          ],
        ),
      ),
    );
  }
}
