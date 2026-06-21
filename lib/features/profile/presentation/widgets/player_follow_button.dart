import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/user_model.dart';
import '../../../../shared/providers/player_social_provider.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/cf_button.dart';

class PlayerFollowButton extends ConsumerWidget {
  const PlayerFollowButton({
    super.key,
    required this.followedUser,
    required this.followerUserId,
    this.compact = false,
    this.showFollowBack = false,
  });

  final UserModel followedUser;
  final String followerUserId;
  final bool compact;
  final bool showFollowBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followingAsync = ref.watch(
      isFollowingPlayerProvider((
        followerId: followerUserId,
        followedId: followedUser.id,
      )),
    );
    final following = followingAsync.valueOrNull ?? false;
    final busy = followingAsync.isLoading;
    final cf = context.cf;

    Future<void> toggle() async {
      final repo = ref.read(playerFollowRepositoryProvider);
      final me = ref.read(currentUserProfileProvider).valueOrNull;
      try {
        if (following) {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Unfollow?'),
              content: Text(
                'Stop following ${followedUser.effectiveName}?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Unfollow'),
                ),
              ],
            ),
          );
          if (confirmed != true) return;
          await repo.unfollowPlayer(
            followerUserId: followerUserId,
            followedUserId: followedUser.id,
          );
        } else {
          await repo.followPlayer(
            followerUserId: followerUserId,
            followedUserId: followedUser.id,
            followerPlayerId: me?.playerId ?? '',
            followedPlayerId: followedUser.playerId ?? '',
            followerName: me?.effectiveName ?? 'Someone',
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not update follow: $e')),
          );
        }
      }
    }

    final label = following
        ? 'Following'
        : (showFollowBack ? 'Follow Back' : 'Follow');

    if (compact) {
      if (following) {
        return OutlinedButton(
          onPressed: busy ? null : toggle,
          style: OutlinedButton.styleFrom(
            foregroundColor: cf.accent,
            side: BorderSide(color: cf.accent),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          child: Text(label),
        );
      }
      return CfButton(
        label: label,
        compact: true,
        isGold: true,
        isLoading: busy,
        onPressed: busy ? null : toggle,
      );
    }

    if (following) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: busy ? null : toggle,
          style: OutlinedButton.styleFrom(
            foregroundColor: cf.accent,
            side: BorderSide(color: cf.accent),
          ),
          child: Text(label),
        ),
      );
    }

    return CfButton(
      label: label,
      isGold: true,
      isLoading: busy,
      onPressed: busy ? null : toggle,
    );
  }
}
