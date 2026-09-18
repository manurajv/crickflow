import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../data/models/series/series.dart';
import '../../../shared/providers/series_providers.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';
import 'widgets/series_ui.dart';
import 'widgets/series_user_name.dart';

class SeriesAuditScreen extends ConsumerWidget {
  const SeriesAuditScreen({super.key, required this.seriesId});
  final String seriesId;

  String _roleLabel(String role) {
    if (role.isEmpty) return '';
    return SeriesRole.parse(role).label;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final role = ref.watch(mySeriesRoleProvider(seriesId));
    if (role != SeriesRole.superAdmin && role != SeriesRole.seriesAdmin) {
      return const Scaffold(
        appBar: CfChromeAppBar(title: Text('Activity log')),
        body: Center(child: Text('Admin access required')),
      );
    }

    return Scaffold(
      backgroundColor: cf.background,
      appBar: const CfChromeAppBar(title: Text('Activity log')),
      body: ref.watch(seriesAuditLogsProvider(seriesId)).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (logs) => logs.isEmpty
                ? const SeriesEmptyState(
                    icon: Icons.history,
                    title: 'No activity yet',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppDimens.spaceMd),
                    itemCount: logs.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: cf.border),
                    itemBuilder: (_, i) {
                      final log = logs[i];
                      final roleLabel = _roleLabel(log.actorRole);
                      final date = seriesShortDate(log.timestamp);
                      return ListTile(
                        leading: Icon(
                          Icons.receipt_long_outlined,
                          color: cf.accent,
                        ),
                        title: Text(seriesAuditActionLabel(log.action)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (roleLabel.isNotEmpty) ...[
                                  Text(
                                    '$roleLabel · ',
                                    style: TextStyle(
                                      color: cf.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                                Flexible(
                                  child: SeriesUserName(
                                    log.actorUserId,
                                    fallback: 'Someone',
                                    style: TextStyle(
                                      color: cf.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (log.reason.isNotEmpty)
                              Text(
                                log.reason,
                                style: TextStyle(
                                  color: cf.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            if (date.isNotEmpty)
                              Text(
                                date,
                                style: TextStyle(
                                  color: cf.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                        isThreeLine: true,
                      );
                    },
                  ),
          ),
    );
  }
}
