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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markAllReadOnOpen());
  }

  Future<void> _markAllReadOnOpen() async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    await ref.read(notificationRepositoryProvider).markAllRead(uid);
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(userNotificationsProvider);

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
      body: notificationsAsync.when(
        data: (list) {
          if (list.isEmpty) {
            final cf = context.cf;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.spaceXl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_none_outlined,
                      size: 64,
                      color: cf.textMuted.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: AppDimens.spaceMd),
                    Text(
                      'All caught up',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: AppDimens.spaceSm),
                    Text(
                      'Team join requests and match updates will appear here.',
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
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              AppDimens.spaceSm,
              AppDimens.spaceMd,
              AppDimens.spaceLg,
            ),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _NotificationCard(notification: list[i]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}

class _NotificationCard extends ConsumerWidget {
  const _NotificationCard({required this.notification});

  final NotificationModel notification;

  Future<void> _onTap(BuildContext context, WidgetRef ref) async {
    await ref.read(notificationRepositoryProvider).markRead(notification.id);
    if (!context.mounted) return;

    if (notification.type == TournamentNotificationTypes.invitation ||
        notification.type == TeamNotificationTypes.invitation) {
      return;
    }

    final route = NotificationNavigation.routeForNotification(notification);
    if (route != null) {
      context.push(route);
    }
  }

  Future<void> _respond(
    BuildContext context,
    WidgetRef ref, {
    required bool accept,
  }) async {
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
        await ref.read(notificationRepositoryProvider).markRead(notification.id);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept ? 'Invitation accepted' : 'Invitation declined'),
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
      await ref.read(notificationRepositoryProvider).markRead(notification.id);
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
    final palette = _paletteForType(n.type, context);
    final actionLabel = n.actionLabel;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: n.isActionable
            ? null
            : () => _onTap(context, ref),
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: n.read
                ? cf.surfaceElevated
                : cf.surfaceElevated.withValues(alpha: 0.98),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: n.read
                  ? cf.border.withValues(alpha: 0.55)
                  : palette.accent.withValues(alpha: 0.45),
            ),
            boxShadow: n.read
                ? null
                : [
                    BoxShadow(
                      color: palette.accent.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: n.read
                        ? Colors.transparent
                        : palette.accent,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(12),
                    ),
                  ),
                ),
                Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.spaceMd,
                    AppDimens.spaceMd,
                    AppDimens.spaceSm,
                    AppDimens.spaceMd,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: palette.background,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(palette.icon, color: palette.accent, size: 22),
                      ),
                      const SizedBox(width: AppDimens.spaceMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _TypeChip(
                                  label: n.typeLabel,
                                  color: palette.accent,
                                ),
                                if (!n.read) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: palette.accent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              n.title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight:
                                    n.read ? FontWeight.w600 : FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              n.body,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cf.textSecondary,
                                height: 1.35,
                              ),
                            ),
                            if (n.createdAt != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                AppDateUtils.timeAgo(n.createdAt!),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: cf.textMuted,
                                ),
                              ),
                            ],
                            if (n.isActionable) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: () => _respond(
                                        context,
                                        ref,
                                        accept: true,
                                      ),
                                      child: const Text('Accept'),
                                    ),
                                  ),
                                  const SizedBox(width: AppDimens.spaceSm),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _respond(
                                        context,
                                        ref,
                                        accept: false,
                                      ),
                                      child: const Text('Reject'),
                                    ),
                                  ),
                                ],
                              ),
                            ] else if (actionLabel != null) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Text(
                                    actionLabel,
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: cf.link,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 12,
                                    color: cf.link,
                                  ),
                                ],
                              ),
                            ],
                            if (n.canReportUnauthorizedAdd) ...[
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: OutlinedButton.icon(
                                  onPressed: () => _reportToAdmin(context, ref),
                                  icon: const Icon(Icons.flag_outlined, size: 16),
                                  label: const Text('Report to admin'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: cf.error,
                                    side: BorderSide(
                                      color: cf.error.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  _NotificationPalette _paletteForType(String? type, BuildContext context) {
    final cf = context.cf;
    return switch (type) {
      TeamNotificationTypes.joinRequest => _NotificationPalette(
          icon: Icons.group_add_outlined,
          accent: cf.link,
          background: cf.accent.withValues(alpha: 0.12),
        ),
      TeamNotificationTypes.invitation => _NotificationPalette(
          icon: Icons.mail_outline,
          accent: cf.accent,
          background: cf.accent.withValues(alpha: 0.12),
        ),
      TeamNotificationTypes.joinAccepted => _NotificationPalette(
          icon: Icons.check_circle_outline,
          accent: cf.success,
          background: cf.success.withValues(alpha: 0.12),
        ),
      TeamNotificationTypes.joinRejected => _NotificationPalette(
          icon: Icons.cancel_outlined,
          accent: cf.error,
          background: cf.error.withValues(alpha: 0.12),
        ),
      TeamNotificationTypes.invitationAccepted => _NotificationPalette(
          icon: Icons.check_circle_outline,
          accent: cf.success,
          background: cf.success.withValues(alpha: 0.12),
        ),
      TeamNotificationTypes.invitationRejected => _NotificationPalette(
          icon: Icons.cancel_outlined,
          accent: cf.error,
          background: cf.error.withValues(alpha: 0.12),
        ),
      TournamentNotificationTypes.invitation ||
      TournamentNotificationTypes.joinRequest =>
        _NotificationPalette(
          icon: Icons.emoji_events_outlined,
          accent: cf.accent,
          background: cf.accent.withValues(alpha: 0.12),
        ),
      TournamentNotificationTypes.joinApproved ||
      TournamentNotificationTypes.invitationAccepted =>
        _NotificationPalette(
          icon: Icons.check_circle_outline,
          accent: cf.success,
          background: cf.success.withValues(alpha: 0.12),
        ),
      TournamentNotificationTypes.joinRejected ||
      TournamentNotificationTypes.invitationRejected =>
        _NotificationPalette(
          icon: Icons.cancel_outlined,
          accent: cf.error,
          background: cf.error.withValues(alpha: 0.12),
        ),
      TeamNotificationTypes.memberRemoved => _NotificationPalette(
          icon: Icons.person_remove_outlined,
          accent: cf.info,
          background: CfColors.primaryBlue.withValues(alpha: 0.15),
        ),
      TeamNotificationTypes.memberAdded => _NotificationPalette(
          icon: Icons.group_add_outlined,
          accent: cf.accent,
          background: cf.accent.withValues(alpha: 0.12),
        ),
      'admin_roster_report' => _NotificationPalette(
          icon: Icons.admin_panel_settings_outlined,
          accent: cf.error,
          background: cf.error.withValues(alpha: 0.12),
        ),
      _ => _NotificationPalette(
          icon: Icons.notifications_outlined,
          accent: cf.info,
          background: CfColors.primaryBlue.withValues(alpha: 0.15),
        ),
    };
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _NotificationPalette {
  const _NotificationPalette({
    required this.icon,
    required this.accent,
    required this.background,
  });

  final IconData icon;
  final Color accent;
  final Color background;
}
