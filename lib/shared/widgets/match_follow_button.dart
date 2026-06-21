import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../shared/providers/notification_provider.dart';
import '../../shared/providers/providers.dart';
import 'match_quick_action_button.dart';

/// Follow / Following toggle for match spectators.
class MatchFollowButton extends ConsumerWidget {
  const MatchFollowButton({
    super.key,
    required this.matchId,
    this.compact = false,
    this.quickAction = false,
  });

  final String matchId;
  final bool compact;
  final bool quickAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).value?.uid;
    if (uid == null || uid.isEmpty) {
      if (quickAction) {
        return MatchQuickActionButton(
          icon: Icons.notifications_none,
          label: 'Follow',
          onPressed: () => _promptSignIn(context),
        );
      }
      return compact
          ? TextButton(
              onPressed: () => _promptSignIn(context),
              child: const Text('Follow'),
            )
          : OutlinedButton(
              onPressed: () => _promptSignIn(context),
              child: const Text('Follow'),
            );
    }

    final followingAsync = ref.watch(matchFollowingProvider(matchId));
    final following = followingAsync.valueOrNull ?? false;
    final busy = followingAsync.isLoading;

    final label = following ? 'Following' : 'Follow';
    final icon = following ? Icons.notifications_active : Icons.notifications_none;

    Future<void> toggle() async {
      final repo = ref.read(matchFollowerRepositoryProvider);
      final service = ref.read(notificationServiceProvider);
      try {
        if (following) {
          await repo.unfollowMatch(matchId: matchId, userId: uid);
          await service.unsubscribeFromMatch(matchId);
        } else {
          await repo.followMatch(matchId: matchId, userId: uid);
          await service.subscribeToMatch(matchId);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not update follow: $e')),
          );
        }
      }
    }

    if (quickAction) {
      return MatchQuickActionButton(
        icon: icon,
        label: label,
        onPressed: busy ? null : toggle,
        highlighted: following,
      );
    }

    if (compact) {
      return TextButton.icon(
        onPressed: busy ? null : toggle,
        icon: Icon(icon, size: 18, color: AppColors.gold),
        label: Text(
          label,
          style: const TextStyle(
            color: AppColors.gold,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: busy ? null : toggle,
      style: OutlinedButton.styleFrom(
        foregroundColor: following ? AppColors.gold : null,
        side: BorderSide(
          color: following
              ? AppColors.gold
              : Theme.of(context).colorScheme.outline,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceSm,
        ),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }

  void _promptSignIn(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sign in to follow this match')),
    );
  }
}
