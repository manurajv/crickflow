import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/cf_search_bar.dart';
import '../../../../shared/widgets/cf_stat_tile.dart';
import '../../models/managed_player.dart';
import '../../models/player_enums.dart';
import '../../models/player_filters.dart';

class PlayersSummaryCards extends StatelessWidget {
  const PlayersSummaryCards({super.key, required this.summary});

  final PlayerSummaryStats summary;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _card(Icons.sports_cricket_outlined, 'Total', '${summary.total}',
          AdminColors.primaryBlue),
      _card(Icons.person_outline, 'Registered', '${summary.registered}',
          context.adminColors.info),
      _card(Icons.person_add_alt_outlined, 'Walk-in', '${summary.walkIn}',
          AdminColors.goldDark),
      _card(Icons.verified_outlined, 'Verified', '${summary.verified}',
          context.adminColors.success),
      _card(Icons.check_circle_outline, 'Active', '${summary.active}',
          const Color(0xFF26A69A)),
      _card(Icons.block_outlined, 'Suspended', '${summary.suspended}',
          context.adminColors.error),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cols = width >= 1200
            ? 3
            : width >= 700
                ? 2
                : 1;
        const spacing = 12.0;
        final itemWidth = (width - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final c in cards) SizedBox(width: itemWidth, child: c),
          ],
        );
      },
    );
  }

  Widget _card(IconData icon, String title, String value, Color accent) {
    return CfStatTile(
      icon: icon,
      title: title,
      value: value,
      accentColor: accent,
      compact: true,
    );
  }
}

class PlayersToolbar extends StatelessWidget {
  const PlayersToolbar({
    super.key,
    required this.controller,
    required this.onQueryChanged,
    required this.onSearchSubmitted,
    required this.onFilter,
    required this.onRefresh,
    this.filterActive = false,
    this.refreshing = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onSearchSubmitted;
  final VoidCallback onFilter;
  final VoidCallback onRefresh;
  final bool filterActive;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CfSearchBar(
          controller: controller,
          hintText: 'Search name, CF ID, user ID…',
          onChanged: onQueryChanged,
          onSubmitted: (_) => onSearchSubmitted(),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            CfButton(
              label: filterActive ? 'Filters •' : 'Filters',
              variant: CfButtonVariant.secondary,
              onPressed: onFilter,
            ),
            const SizedBox(width: 8),
            CfButton(
              label: refreshing ? 'Refreshing…' : 'Refresh',
              variant: CfButtonVariant.ghost,
              onPressed: refreshing ? null : onRefresh,
            ),
          ],
        ),
      ],
    );
  }
}

Future<PlayerListFilters?> showPlayersFilterDrawer({
  required BuildContext context,
  required PlayerListFilters initial,
}) async {
  var draft = initial;
  return showGeneralDialog<PlayerListFilters>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Filters',
    pageBuilder: (ctx, a1, a2) {
      return Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: Theme.of(ctx).colorScheme.surface,
          child: SizedBox(
            width: 360,
            height: MediaQuery.sizeOf(ctx).height,
            child: StatefulBuilder(
              builder: (ctx, setLocal) {
                return SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Player filters',
                                style: Theme.of(ctx).textTheme.titleLarge,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(ctx),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Registered only'),
                              value: draft.registeredOnly,
                              onChanged: (v) => setLocal(() {
                                draft = draft.copyWith(
                                  registeredOnly: v,
                                  walkInOnly: v ? false : draft.walkInOnly,
                                );
                              }),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Walk-in only'),
                              value: draft.walkInOnly,
                              onChanged: (v) => setLocal(() {
                                draft = draft.copyWith(
                                  walkInOnly: v,
                                  registeredOnly:
                                      v ? false : draft.registeredOnly,
                                );
                              }),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Include deleted'),
                              value: draft.includeDeleted,
                              onChanged: (v) => setLocal(() {
                                draft = draft.copyWith(includeDeleted: v);
                              }),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Include archived'),
                              value: draft.includeArchived,
                              onChanged: (v) => setLocal(() {
                                draft = draft.copyWith(includeArchived: v);
                              }),
                            ),
                            const SizedBox(height: 8),
                            Text('Status', style: Theme.of(ctx).textTheme.titleSmall),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final s in ManagedPlayerStatus.values)
                                  FilterChip(
                                    label: Text(s.label),
                                    selected: draft.statuses.contains(s),
                                    onSelected: (sel) => setLocal(() {
                                      final next = {...draft.statuses};
                                      if (sel) {
                                        next.add(s);
                                      } else {
                                        next.remove(s);
                                      }
                                      draft = draft.copyWith(statuses: next);
                                    }),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              decoration: const InputDecoration(
                                labelText: 'Country',
                              ),
                              controller:
                                  TextEditingController(text: draft.country ?? ''),
                              onChanged: (v) => setLocal(() {
                                draft = v.trim().isEmpty
                                    ? draft.copyWith(clearCountry: true)
                                    : draft.copyWith(country: v.trim());
                              }),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              decoration: const InputDecoration(
                                labelText: 'City',
                              ),
                              controller:
                                  TextEditingController(text: draft.city ?? ''),
                              onChanged: (v) => setLocal(() {
                                draft = v.trim().isEmpty
                                    ? draft.copyWith(clearCity: true)
                                    : draft.copyWith(city: v.trim());
                              }),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: CfButton(
                                label: 'Reset',
                                variant: CfButtonVariant.secondary,
                                onPressed: () =>
                                    Navigator.pop(ctx, PlayerListFilters.empty),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: CfButton(
                                label: 'Apply',
                                onPressed: () => Navigator.pop(ctx, draft),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
    },
  );
}
