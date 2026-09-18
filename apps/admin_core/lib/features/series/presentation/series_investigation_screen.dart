import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/permission_gate.dart';
import '../../../models/admin_permission.dart';
import '../../../shared/widgets/cf_responsive_table.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/managed_series.dart';
import '../providers/series_admin_providers.dart';

class SeriesInvestigationScreen extends ConsumerWidget {
  const SeriesInvestigationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(managedSeriesListProvider);
    return PermissionGate(
      permission: AdminPermission.canAccessGlobalData,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Series investigation',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          const Text(
            'Inspect Series ownership, clubs, admins, and audit activity.',
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Search name, ID, or owner',
            ),
            onSubmitted: (value) =>
                ref.read(seriesSearchProvider.notifier).state = value,
          ),
          const SizedBox(height: 16),
          items.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Could not load series: $e'),
            data: (series) => Card(
              clipBehavior: Clip.antiAlias,
              child: CfResponsiveTable(
                minWidth: 700,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Series')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Clubs')),
                    DataColumn(label: Text('Players')),
                    DataColumn(label: Text('Action')),
                  ],
                  rows: series
                      .map(
                        (s) => DataRow(
                          cells: [
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 200),
                                child: Text(
                                  s.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(Text(s.status)),
                            DataCell(Text('${s.clubCount}')),
                            DataCell(Text('${s.playerCount}')),
                            DataCell(
                              IconButton(
                                tooltip: 'Investigate',
                                icon: const Icon(Icons.open_in_new),
                                onPressed: () => _showDetail(context, ref, s),
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDetail(
    BuildContext context,
    WidgetRef ref,
    ManagedSeries series,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Consumer(
        builder: (_, dialogRef, _) {
          final detail = dialogRef.watch(
            seriesInvestigationProvider(series.id),
          );
          return AlertDialog(
            title: Text(series.name),
            content: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 680,
                maxHeight: 600,
              ),
              child: SingleChildScrollView(
                child: detail.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (e, _) => Text('$e'),
                  data: (value) => value == null
                      ? const Text('Series no longer exists')
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Owner: ${value.series.superAdminUserId}'),
                            Text('Clubs: ${value.clubs.length}'),
                            Text('Series admins: ${value.admins.length}'),
                            Text('Audit events: ${value.auditLogs.length}'),
                            const SizedBox(height: 16),
                            const Text(
                              'Clubs',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            ...value.clubs
                                .take(20)
                                .map(
                                  (club) => ListTile(
                                    dense: true,
                                    title: Text(
                                      '${club['name'] ?? club['id']}',
                                    ),
                                    subtitle: Text('${club['status'] ?? ''}'),
                                  ),
                                ),
                          ],
                        ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
              if (series.status != 'suspended')
                FilledButton.tonal(
                  onPressed: () async {
                    final actor = ref.read(adminSessionProvider).adminUser;
                    if (actor == null) return;
                    await ref
                        .read(seriesAdminRepositoryProvider)
                        .suspendSeries(series, actorId: actor.uid);
                    ref.invalidate(managedSeriesListProvider);
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
                  child: const Text('Suspend series'),
                ),
            ],
          );
        },
      ),
    );
  }
}
