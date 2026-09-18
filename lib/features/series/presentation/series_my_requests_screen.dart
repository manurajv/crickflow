import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../data/models/series/series.dart';
import '../../../shared/providers/series_providers.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';
import 'widgets/series_ui.dart';

final mySeriesApprovalsProvider =
    StreamProvider.family<List<SeriesApprovalModel>, String>((ref, seriesId) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null || seriesId.isEmpty) {
    return Stream.value(const []);
  }
  return ref.watch(seriesApprovalRepositoryProvider).watchMyApprovals(
        seriesId: seriesId,
        userId: uid,
      );
});

/// Signed-in user's Orgs requests for this organization (any status).
class SeriesMyRequestsScreen extends ConsumerWidget {
  const SeriesMyRequestsScreen({super.key, required this.seriesId});
  final String seriesId;

  String _titleFor(SeriesApprovalModel item) {
    final metaName = item.metadata['displayName']?.toString().trim() ??
        item.metadata['clubName']?.toString().trim() ??
        item.metadata['name']?.toString().trim() ??
        item.metadata['clubAName']?.toString().trim() ??
        '';
    if (metaName.isNotEmpty) {
      return '${item.targetType.label} · $metaName';
    }
    return item.targetType.label;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    if (FirebaseAuth.instance.currentUser == null) {
      return const Scaffold(
        appBar: CfChromeAppBar(title: Text('My requests')),
        body: Center(child: Text('Sign in to view your requests')),
      );
    }
    return Scaffold(
      backgroundColor: cf.background,
      appBar: const CfChromeAppBar(title: Text('My requests')),
      body: ref.watch(mySeriesApprovalsProvider(seriesId)).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (items) => items.isEmpty
                ? const SeriesEmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'No requests yet',
                    message:
                        'Join requests, registrations, and proposals you submit appear here.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppDimens.spaceMd),
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppDimens.spaceSm),
                    itemBuilder: (_, i) {
                      final item = items[i];
                      return Card(
                        color: cf.surface,
                        child: ListTile(
                          title: Text(_titleFor(item)),
                          subtitle: Text(item.status.label),
                          trailing: Icon(
                            item.status == SeriesApprovalStatus.approved
                                ? Icons.check_circle_outline
                                : item.status == SeriesApprovalStatus.rejected
                                    ? Icons.cancel_outlined
                                    : Icons.hourglass_empty,
                            color: item.status == SeriesApprovalStatus.approved
                                ? Colors.green
                                : item.status == SeriesApprovalStatus.rejected
                                    ? Colors.redAccent
                                    : cf.textSecondary,
                          ),
                        ),
                      );
                    },
                  ),
          ),
    );
  }
}
