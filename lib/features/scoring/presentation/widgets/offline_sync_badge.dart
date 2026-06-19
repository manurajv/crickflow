import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/cf_colors.dart';
import '../../../../data/local/pending_sync_action.dart';
import '../../../../shared/providers/offline_sync_provider.dart';

/// Shows ONLINE / OFFLINE / SYNCING status with pending sync count.
class OfflineSyncBadge extends ConsumerWidget {
  const OfflineSyncBadge({super.key, required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncMeta = ref.watch(matchSyncMetaProvider(matchId));
    final cf = context.cf;

    return syncMeta.when(
      data: (meta) {
        final (label, color, icon) = switch (meta.status) {
          ConnectivityStatus.syncing => (
              'SYNCING',
              cf.info,
              Icons.cloud_sync,
            ),
          ConnectivityStatus.offline => (
              'OFFLINE',
              cf.statusUpcoming,
              Icons.cloud_off,
            ),
          ConnectivityStatus.online => meta.pendingCount > 0
              ? (
                  'SYNC PENDING',
                  cf.statusUpcoming,
                  Icons.cloud_upload_outlined,
                )
              : (
                  'ONLINE',
                  cf.success,
                  Icons.cloud_done_outlined,
                ),
        };

        final lastSync = meta.lastSyncAt;
        final lastSyncLabel = lastSync == null
            ? 'Not synced yet'
            : 'Last sync ${DateFormat.jm().format(lastSync)}';

        return Material(
          color: color.withValues(alpha: 0.12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          letterSpacing: 0.4,
                          color: color,
                        ),
                      ),
                      Text(
                        meta.pendingCount > 0
                            ? '$lastSyncLabel · ${meta.pendingCount} pending'
                            : lastSyncLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: cf.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
