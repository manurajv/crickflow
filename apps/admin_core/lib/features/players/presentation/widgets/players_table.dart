import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../../../shared/widgets/cf_empty_state.dart';
import '../../../../shared/widgets/cf_loading_state.dart';
import '../../../../shared/widgets/cf_network_image.dart';
import '../../models/managed_player.dart';
import '../../models/player_enums.dart';
import 'player_status_badge.dart';

class PlayersTable extends StatelessWidget {
  const PlayersTable({
    super.key,
    required this.players,
    required this.sort,
    required this.isLoading,
    required this.hasMore,
    required this.isLoadingMore,
    required this.selectedId,
    required this.onSort,
    required this.onSelect,
    required this.onLoadMore,
  });

  final List<ManagedPlayer> players;
  final PlayerSort sort;
  final bool isLoading;
  final bool hasMore;
  final bool isLoadingMore;
  final String? selectedId;
  final ValueChanged<PlayerSortField> onSort;
  final ValueChanged<ManagedPlayer> onSelect;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (isLoading && players.isEmpty) {
      return const CfCard(
        child: SizedBox(
          height: 280,
          child: CfLoadingState(message: 'Loading players…'),
        ),
      );
    }

    if (!isLoading && players.isEmpty) {
      return const CfCard(
        child: SizedBox(
          height: 240,
          child: CfEmptyState(
            icon: Icons.sports_cricket_outlined,
            title: 'No players found',
            message: 'Try adjusting search or filters.',
          ),
        ),
      );
    }

    final colors = context.adminColors;
    final df = DateFormat('yyyy-MM-dd');

    return CfCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              columns: [
                _col('Name', PlayerSortField.name),
                const DataColumn(label: Text('CF ID')),
                const DataColumn(label: Text('Type')),
                const DataColumn(label: Text('Role')),
                _col('Matches', PlayerSortField.matches),
                _col('Runs', PlayerSortField.runs),
                _col('Wickets', PlayerSortField.wickets),
                const DataColumn(label: Text('Location')),
                const DataColumn(label: Text('Status')),
                _col('Created', PlayerSortField.createdAt),
              ],
              rows: [
                for (final p in players)
                  DataRow(
                    selected: p.id == selectedId,
                    onSelectChanged: (_) => onSelect(p),
                    color: WidgetStateProperty.resolveWith((states) {
                      if (p.id == selectedId) {
                        return colors.info.withValues(alpha: 0.08);
                      }
                      return null;
                    }),
                    cells: [
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CfAvatar(
                              url: p.photoUrl,
                              radius: 14,
                              label: p.displayName,
                            ),
                            const SizedBox(width: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 160),
                              child: Text(
                                p.displayName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(Text(p.cfIdLabel)),
                      DataCell(Text(p.isRegistered ? 'Registered' : 'Walk-in')),
                      DataCell(Text(p.role.isEmpty ? '—' : p.role)),
                      DataCell(Text('${p.matchesPlayed}')),
                      DataCell(Text('${p.runs}')),
                      DataCell(Text('${p.wickets}')),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 140),
                          child: Text(
                            p.locationLabel,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(PlayerStatusBadge(status: p.displayStatus)),
                      DataCell(
                        Text(
                          p.createdAt == null ? '—' : df.format(p.createdAt!),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (hasMore)
            Padding(
              padding: const EdgeInsets.all(12),
              child: CfButton(
                label: isLoadingMore ? 'Loading…' : 'Load more',
                variant: CfButtonVariant.secondary,
                onPressed: isLoadingMore ? null : onLoadMore,
              ),
            ),
        ],
      ),
    );
  }

  DataColumn _col(String label, PlayerSortField field) {
    final active = sort.field == field;
    return DataColumn(
      label: InkWell(
        onTap: () => onSort(field),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            if (active)
              Icon(
                sort.descending ? Icons.arrow_downward : Icons.arrow_upward,
                size: 14,
              ),
          ],
        ),
      ),
    );
  }
}
