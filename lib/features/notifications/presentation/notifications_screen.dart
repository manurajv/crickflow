import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/notification_navigation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/notification_model.dart';
import '../../../shared/providers/notification_provider.dart';
import '../../../shared/providers/providers.dart';

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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.spaceXl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_none_outlined,
                      size: 64,
                      color: AppColors.textSecondary.withValues(alpha: 0.4),
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
                            color: AppColors.textSecondary,
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

    final route = NotificationNavigation.routeForNotification(notification);
    if (route != null) {
      context.push(route);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = notification;
    final theme = Theme.of(context);
    final palette = _paletteForType(n.type);
    final actionLabel = n.actionLabel;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onTap(context, ref),
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: n.read
                ? AppColors.surfaceElevated
                : AppColors.surfaceElevated.withValues(alpha: 0.98),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: n.read
                  ? AppColors.border.withValues(alpha: 0.55)
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 92,
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
                                color: AppColors.textSecondary,
                                height: 1.35,
                              ),
                            ),
                            if (n.createdAt != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                AppDateUtils.timeAgo(n.createdAt!),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                            if (actionLabel != null) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Text(
                                    actionLabel,
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: AppColors.gold,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 12,
                                    color: AppColors.gold.withValues(alpha: 0.9),
                                  ),
                                ],
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
    );
  }

  _NotificationPalette _paletteForType(String? type) {
    return switch (type) {
      'team_join_request' => _NotificationPalette(
          icon: Icons.group_add_outlined,
          accent: AppColors.gold,
          background: AppColors.gold.withValues(alpha: 0.12),
        ),
      'team_join_accepted' => _NotificationPalette(
          icon: Icons.check_circle_outline,
          accent: AppColors.accentGreen,
          background: AppColors.accentGreen.withValues(alpha: 0.12),
        ),
      'team_join_rejected' => _NotificationPalette(
          icon: Icons.cancel_outlined,
          accent: AppColors.accentRed,
          background: AppColors.accentRed.withValues(alpha: 0.12),
        ),
      'team_member_removed' => _NotificationPalette(
          icon: Icons.person_remove_outlined,
          accent: AppColors.primaryBlueLight,
          background: AppColors.primaryBlue.withValues(alpha: 0.15),
        ),
      _ => _NotificationPalette(
          icon: Icons.notifications_outlined,
          accent: AppColors.primaryBlueLight,
          background: AppColors.primaryBlue.withValues(alpha: 0.15),
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
