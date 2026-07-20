import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/team_notification_types.dart';
import '../../../core/constants/tournament_notification_types.dart';
import '../../../core/navigation/notification_navigation.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/notification_model.dart';
import '../../../shared/providers/notification_provider.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/tournament_providers.dart';
import '../../../shared/providers/tournament_team_request_provider.dart';
import '../../teams/domain/team_notification_actions.dart';
import '../../tournaments/domain/tournament_notification_actions.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels < pos.maxScrollExtent - 240) return;

    final feed = ref.read(notificationsFeedProvider);
    if (feed.loadingMore || !feed.hasMore) return;
    ref.read(notificationsFeedProvider.notifier).loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(notificationsFeedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              final uid = ref.read(authStateProvider).value?.uid;
              if (uid != null) {
                await ref
                    .read(notificationRepositoryProvider)
                    .markAllRead(uid);
              }
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: _buildBody(context, feed),
    );
  }

  Widget _buildBody(BuildContext context, NotificationsFeedState feed) {
    if (feed.loading && feed.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (feed.error != null && feed.items.isEmpty) {
      return Center(child: Text('${feed.error}'));
    }
    if (feed.items.isEmpty) {
      final cf = context.cf;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceXl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.notifications_none_outlined,
                size: 56,
                color: cf.textMuted.withValues(alpha: 0.4),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              Text(
                'All caught up',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppDimens.spaceSm),
              Text(
                'Match updates, invites, and achievements will appear here.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cf.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    final list = feed.items;
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      itemCount: list.length + (feed.loadingMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        if (i >= list.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return _NotificationCard(
          key: ValueKey(list[i].id),
          notification: list[i],
        );
      },
    );
  }
}

class _NotificationCard extends ConsumerWidget {
  const _NotificationCard({super.key, required this.notification});

  final NotificationModel notification;

  Future<void> _onTap(BuildContext context, WidgetRef ref) async {
    if (!notification.read) {
      await ref.read(notificationRepositoryProvider).markRead(notification.id);
    }
    if (!context.mounted) return;

    if (notification.isActionable) return;

    final route = NotificationNavigation.routeForNotification(notification);
    if (route != null) {
      context.push(route);
    } else if (notification.matchId != null &&
        notification.matchId!.isNotEmpty) {
      context.push('/match/${notification.matchId}');
    }
  }

  Future<void> _respond(
    BuildContext context,
    WidgetRef ref, {
    required bool accept,
  }) async {
    if (notification.hasActionStatus) return;
    try {
      if (notification.type == TeamNotificationTypes.invitation) {
        if (accept) {
          await TeamNotificationActions.accept(
            ref,
            notification: notification,
          );
        } else {
          await TeamNotificationActions.reject(
            ref,
            notification: notification,
          );
        }
        await ref.read(notificationRepositoryProvider).setActionStatus(
              notification.id,
              accept ? 'accepted' : 'rejected',
            );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accept ? 'Invitation accepted' : 'Invitation declined',
            ),
          ),
        );
        return;
      }

      if (accept) {
        await TournamentNotificationActions.accept(
          ref,
          notification: notification,
        );
      } else {
        await TournamentNotificationActions.reject(
          ref,
          notification: notification,
        );
      }
      await ref.read(notificationRepositoryProvider).setActionStatus(
            notification.id,
            accept ? 'accepted' : 'rejected',
          );
      final tournamentId = notification.tournamentId;
      if (tournamentId != null && tournamentId.isNotEmpty) {
        ref.invalidate(tournamentTeamRequestsProvider(tournamentId));
        ref.invalidate(tournamentProvider(tournamentId));
        ref.invalidate(tournamentOfficialsProvider(tournamentId));
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? (notification.type ==
                        TournamentNotificationTypes.invitation
                    ? 'Invitation accepted'
                    : 'Accepted')
                : (notification.type ==
                        TournamentNotificationTypes.invitation
                    ? 'Invitation declined'
                    : 'Rejected'),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<void> _reportToAdmin(BuildContext context, WidgetRef ref) async {
    final uid = ref.read(authStateProvider).value?.uid;
    final n = notification;
    if (uid == null || n.teamId == null || n.teamId!.isEmpty) return;

    final messageController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report to admin'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Tell us if you were added to this team without your consent. '
              'CrickFlow support will review your report.',
            ),
            const SizedBox(height: AppDimens.spaceMd),
            TextField(
              controller: messageController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Details (optional)',
                hintText: 'I do not know this team…',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit report'),
          ),
        ],
      ),
    );

    final message = messageController.text.trim();
    messageController.dispose();

    if (confirmed != true || !context.mounted) return;

    try {
      final profile = await ref.read(currentUserProfileProvider.future);
      final player =
          await ref.read(playerRepositoryProvider).getPlayerByUserId(uid);
      final team =
          await ref.read(teamRepositoryProvider).getTeam(n.teamId!);
      final reporterName =
          profile?.displayName ?? profile?.name ?? 'CrickFlow player';

      await ref.read(teamRosterReportRepositoryProvider).submitReport(
            reporterUserId: uid,
            reporterName: reporterName,
            teamId: n.teamId!,
            teamName: team?.name ?? 'Unknown team',
            playerId: n.playerId ?? player?.id ?? uid,
            addedByUserId: n.addedByUserId,
            message: message,
          );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted. Support will review it.'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final n = notification;
    final theme = Theme.of(context);
    final accent = _accentFor(n, context);
    final matchHeader = n.displayMatchHeader;
    final detail1 = n.detailPrimary;
    final detail2 = n.detailSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onTap(context, ref),
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            color: n.read
                ? cf.surfaceElevated
                : accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: n.read
                  ? cf.border.withValues(alpha: 0.45)
                  : accent.withValues(alpha: 0.35),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!n.read)
                  Container(
                    width: 3,
                    height: 36,
                    margin: const EdgeInsets.only(right: 8, top: 2),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  )
                else
                  const SizedBox(width: 11),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(n.categoryIcon, color: accent, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (matchHeader != null) ...[
                        Text(
                          matchHeader,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: cf.textSecondary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.1,
                          ),
                        ),
                        const SizedBox(height: 1),
                      ],
                      Text(
                        n.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight:
                              n.read ? FontWeight.w600 : FontWeight.w800,
                          height: 1.2,
                          fontSize: 13.5,
                        ),
                      ),
                      if (detail1.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          detail1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cf.textSecondary,
                            height: 1.25,
                          ),
                        ),
                      ],
                      if (detail2 != null) ...[
                        Text(
                          detail2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cf.textMuted,
                            height: 1.25,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (n.createdAt != null)
                            Text(
                              AppDateUtils.timeAgo(n.createdAt!),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cf.textMuted,
                                fontSize: 10.5,
                              ),
                            ),
                          const Spacer(),
                          if (n.hasActionStatus)
                            _StatusChip(
                              label: n.actionStatusLabel ?? '',
                              color: accent,
                            ),
                        ],
                      ),
                      if (n.isActionable) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 32,
                                child: FilledButton(
                                  onPressed: () => _respond(
                                    context,
                                    ref,
                                    accept: true,
                                  ),
                                  style: FilledButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    textStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  child: const Text('Accept'),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SizedBox(
                                height: 32,
                                child: OutlinedButton(
                                  onPressed: () => _respond(
                                    context,
                                    ref,
                                    accept: false,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    textStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  child: const Text('Decline'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (n.canReportUnauthorizedAdd) ...[
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => _reportToAdmin(context, ref),
                            icon: Icon(
                              Icons.flag_outlined,
                              size: 14,
                              color: cf.error,
                            ),
                            label: Text(
                              'Report',
                              style: TextStyle(
                                color: cf.error,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _accentFor(NotificationModel n, BuildContext context) {
    final cf = context.cf;
    return switch (n.categoryKey) {
      'live_match' => cf.error,
      'match' => CfColors.primaryBlue,
      'achievement' || 'badge' => cf.accent,
      'tournament' => cf.accent,
      'team' || 'invitation' => cf.link,
      'social' || 'friend' => cf.success,
      'streaming' => cf.info,
      'system' => cf.info,
      _ => cf.info,
    };
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
