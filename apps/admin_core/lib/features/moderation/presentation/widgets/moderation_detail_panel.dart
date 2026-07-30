import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../models/admin_permission.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/cf_loading_state.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../models/managed_moderation.dart';
import '../../models/moderation_enums.dart';
import '../../providers/moderation_providers.dart';
import 'moderation_status_badge.dart';

class ModerationDetailPanel extends ConsumerWidget {
  const ModerationDetailPanel({
    super.key,
    required this.surface,
    required this.onClose,
  });

  final ModerationSurface surface;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(selectedModerationPostProvider(surface));
    final colors = context.adminColors;
    final checker = ref.watch(permissionCheckerProvider);
    final canModerateCommunity =
        checker.can(AdminPermission.canModerateCommunity);
    final canManageDiscover = checker.can(AdminPermission.canManageDiscover);

    return Material(
      color: colors.surface,
      elevation: 8,
      child: SizedBox(
        width: 460,
        child: async.when(
          loading: () => const CfLoadingState(message: 'Loading post…'),
          error: (e, _) => Center(child: Text('$e')),
          data: (post) {
            if (post == null) {
              return const Center(child: Text('Select a post'));
            }
            return DefaultTabController(
              length: 5,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
                    child: Row(
                      children: [
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Post details',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton(
                          onPressed: onClose,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const _PrivacyBanner(),
                  TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: const [
                      Tab(text: 'Overview'),
                      Tab(text: 'Media'),
                      Tab(text: 'Engagement'),
                      Tab(text: 'Reports'),
                      Tab(text: 'Audit'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _OverviewTab(
                          surface: surface,
                          post: post,
                          canModerateCommunity: canModerateCommunity,
                          canManageDiscover: canManageDiscover,
                        ),
                        _MediaTab(post: post),
                        _EngagementTab(post: post),
                        _ReportsTab(post: post),
                        _AuditTab(surface: surface),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PrivacyBanner extends StatelessWidget {
  const _PrivacyBanner();

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.warning.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, size: 18, color: colors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Moderation view — private chat messages are never displayed.',
              style: TextStyle(
                color: colors.warning,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({
    required this.surface,
    required this.post,
    required this.canModerateCommunity,
    required this.canManageDiscover,
  });

  final ModerationSurface surface;
  final ManagedModerationPost post;
  final bool canModerateCommunity;
  final bool canManageDiscover;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = post;
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
    final canAct = p.source == ModerationSource.discover
        ? canManageDiscover
        : canModerateCommunity;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        _Hero(post: p),
        const SizedBox(height: 16),
        _KeyValue('Post ID', p.id),
        _KeyValue('Author ID', p.authorId.isEmpty ? '—' : p.authorId),
        _KeyValue('Player ID', p.authorPlayerId ?? '—'),
        _KeyValue('Source', p.source.name),
        _KeyValue('Location', p.locationLabel),
        if (p.tournamentId != null)
          _KeyValue('Tournament ID', p.tournamentId!),
        if (p.tournamentName != null)
          _KeyValue('Tournament', p.tournamentName!),
        if (p.matchId != null) _KeyValue('Match ID', p.matchId!),
        if (p.teamId != null) _KeyValue('Team ID', p.teamId!),
        if (p.tags.isNotEmpty) _KeyValue('Tags', p.tags.join(', ')),
        _KeyValue(
          'Created',
          p.createdAt == null ? '—' : dateFmt.format(p.createdAt!),
        ),
        _KeyValue(
          'Updated',
          p.updatedAt == null ? '—' : dateFmt.format(p.updatedAt!),
        ),
        const SizedBox(height: 12),
        const _SectionTitle('Content'),
        const SizedBox(height: 8),
        if (p.title.isNotEmpty) ...[
          Text(
            p.title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
        ],
        Text(p.body.isEmpty ? '—' : p.body),
        if (canAct) ...[
          const SizedBox(height: 16),
          _Actions(surface: surface, post: p),
        ],
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.post});

  final ManagedModerationPost post;

  @override
  Widget build(BuildContext context) {
    final p = post;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          p.displayTitle,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          p.authorName.isEmpty ? 'Unknown author' : p.authorName,
          style: TextStyle(color: context.adminColors.textMuted),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ModerationPostStatusBadge(status: p.status),
            ModerationSourceBadge(source: p.source),
            if (p.featured)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: context.adminColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Featured',
                  style: TextStyle(
                    color: context.adminColors.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (p.pinned)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: context.adminColors.info.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Pinned',
                  style: TextStyle(
                    color: context.adminColors.info,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _MediaTab extends StatelessWidget {
  const _MediaTab({required this.post});

  final ManagedModerationPost post;

  void _showFullImage(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Unable to load image'),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = post;
    final urls = p.mediaUrls.isNotEmpty
        ? p.mediaUrls
        : (p.thumbnailUrl != null ? [p.thumbnailUrl!] : <String>[]);

    if (urls.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'No media attached',
            style: TextStyle(color: context.adminColors.textMuted),
          ),
        ],
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: urls.length,
      itemBuilder: (context, index) {
        final url = urls[index];
        return InkWell(
          onTap: () => _showFullImage(context, url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: context.adminColors.background,
                    child: Icon(Icons.broken_image_outlined,
                        color: context.adminColors.textMuted),
                  ),
                ),
                if (p.hasVideo && index == 0)
                  Center(
                    child: Icon(Icons.play_circle_fill,
                        size: 40,
                        color: Colors.white.withValues(alpha: 0.85)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EngagementTab extends StatelessWidget {
  const _EngagementTab({required this.post});

  final ManagedModerationPost post;

  @override
  Widget build(BuildContext context) {
    final p = post;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const _SectionTitle('Engagement'),
        const SizedBox(height: 8),
        _KeyValue('Likes', '${p.likeCount}'),
        _KeyValue('Comments', '${p.commentCount}'),
        _KeyValue('Shares', '${p.shareCount}'),
        _KeyValue('Views', '${p.viewCount}'),
        _KeyValue('Reports', '${p.reportCount}'),
        const SizedBox(height: 16),
        const _SectionTitle('Comments moderation'),
        const SizedBox(height: 8),
        Text(
          'Nested comments moderation coming soon',
          style: TextStyle(color: context.adminColors.textMuted),
        ),
      ],
    );
  }
}

class _ReportsTab extends StatelessWidget {
  const _ReportsTab({required this.post});

  final ManagedModerationPost post;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const _SectionTitle('Reports'),
        const SizedBox(height: 8),
        _KeyValue('Report count', '${post.reportCount}'),
        const SizedBox(height: 12),
        Text(
          post.reportCount > 0
              ? 'Open the Reports section to resolve individual reports for this post.'
              : 'No reports filed against this post.',
          style: TextStyle(color: context.adminColors.textMuted),
        ),
      ],
    );
  }
}

class _AuditTab extends ConsumerWidget {
  const _AuditTab({required this.surface});

  final ModerationSurface surface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(moderationAuditProvider(surface));
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const _SectionTitle('Audit Log'),
        const SizedBox(height: 8),
        async.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
          data: (items) => items.isEmpty
              ? Text(
                  'No admin actions yet',
                  style: TextStyle(color: context.adminColors.textMuted),
                )
              : Column(
                  children: [
                    for (final item in items.take(30))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.action),
                        subtitle: Text(item.reason ?? item.actorEmail),
                        trailing: Text(
                          DateFormat('MMM d HH:mm').format(item.timestamp),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.surface, required this.post});

  final ModerationSurface surface;
  final ManagedModerationPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller =
        ref.read(moderationHubControllerProvider(surface).notifier);
    final p = post;
    final isDiscover = p.source == ModerationSource.discover;

    Future<void> confirmAction({
      required String title,
      required String message,
      required Future<void> Function(String? reason) run,
      bool danger = false,
    }) async {
      final reasonController = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                ),
              ),
            ],
          ),
          actions: [
            CfButton(
              label: 'Cancel',
              variant: CfButtonVariant.ghost,
              onPressed: () => Navigator.pop(context, false),
            ),
            CfButton(
              label: 'Confirm',
              variant:
                  danger ? CfButtonVariant.danger : CfButtonVariant.primary,
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      );
      if (ok == true) {
        await run(
          reasonController.text.trim().isEmpty
              ? null
              : reasonController.text.trim(),
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title completed')),
          );
        }
      }
      reasonController.dispose();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Actions'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (!isDiscover) ...[
              if (p.status != ManagedPostAdminStatus.hidden)
                OutlinedButton(
                  onPressed: () => confirmAction(
                    title: 'Hide',
                    message: 'Hide this community post from feeds?',
                    run: (r) => controller.hideCommunity(p, reason: r),
                  ),
                  child: const Text('Hide'),
                ),
              if (p.status != ManagedPostAdminStatus.removed)
                OutlinedButton(
                  onPressed: () => confirmAction(
                    title: 'Remove',
                    message: 'Remove this community post?',
                    danger: true,
                    run: (r) => controller.removeCommunity(p, reason: r),
                  ),
                  child: const Text('Remove'),
                ),
              if (p.status == ManagedPostAdminStatus.removed ||
                  p.status == ManagedPostAdminStatus.hidden)
                OutlinedButton(
                  onPressed: () => confirmAction(
                    title: 'Restore',
                    message: 'Restore this community post?',
                    run: (r) => controller.restoreCommunity(p, reason: r),
                  ),
                  child: const Text('Restore'),
                ),
              OutlinedButton(
                onPressed: () => confirmAction(
                  title: p.featured ? 'Unfeature' : 'Feature',
                  message: p.featured
                      ? 'Remove community feature flag?'
                      : 'Feature this community post?',
                  run: (r) =>
                      controller.featureCommunity(p, !p.featured, reason: r),
                ),
                child: Text(p.featured ? 'Unfeature' : 'Feature'),
              ),
            ] else ...[
              if (p.status != ManagedPostAdminStatus.removed)
                OutlinedButton(
                  onPressed: () => confirmAction(
                    title: 'Remove',
                    message: 'Remove this discover post?',
                    danger: true,
                    run: (r) => controller.removeDiscover(p, reason: r),
                  ),
                  child: const Text('Remove'),
                ),
              if (p.status == ManagedPostAdminStatus.removed)
                OutlinedButton(
                  onPressed: () => confirmAction(
                    title: 'Restore',
                    message: 'Restore this discover post?',
                    run: (r) => controller.restoreDiscover(p, reason: r),
                  ),
                  child: const Text('Restore'),
                ),
              OutlinedButton(
                onPressed: () => confirmAction(
                  title: p.featured ? 'Unfeature' : 'Feature',
                  message: p.featured
                      ? 'Remove discover feature flag?'
                      : 'Feature this discover post?',
                  run: (r) =>
                      controller.featureDiscover(p, !p.featured, reason: r),
                ),
                child: Text(p.featured ? 'Unfeature' : 'Feature'),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: context.adminColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
    );
  }
}
