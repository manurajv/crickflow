import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/cf_colors.dart';
import '../../../../../shared/providers/providers.dart';
import '../../../../../shared/providers/team_profile_provider.dart';
import '../../../../../shared/widgets/cf_button.dart';

class TeamFollowButton extends ConsumerStatefulWidget {
  const TeamFollowButton({
    super.key,
    required this.teamId,
    required this.teamName,
    this.compact = false,
  });

  final String teamId;
  final String teamName;
  final bool compact;

  @override
  ConsumerState<TeamFollowButton> createState() => _TeamFollowButtonState();
}

class _TeamFollowButtonState extends ConsumerState<TeamFollowButton> {
  bool _busy = false;
  bool? _optimisticFollowing;

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authStateProvider).value?.uid;
    final cf = context.cf;

    if (uid == null || uid.isEmpty) {
      return const SizedBox.shrink();
    }

    final followKey = (teamId: widget.teamId, userId: uid);
    final followingAsync = ref.watch(isFollowingTeamProvider(followKey));
    final serverFollowing = followingAsync.valueOrNull ?? false;

    // Drop optimistic override once the stream matches it.
    if (_optimisticFollowing != null &&
        followingAsync.hasValue &&
        serverFollowing == _optimisticFollowing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_optimisticFollowing != null &&
            serverFollowing == _optimisticFollowing) {
          setState(() => _optimisticFollowing = null);
        }
      });
    }

    final following = _optimisticFollowing ?? serverFollowing;

    Future<void> toggle() async {
      if (_busy) return;
      final messenger = ScaffoldMessenger.of(context);
      final wasFollowing = following;
      setState(() {
        _busy = true;
        _optimisticFollowing = !wasFollowing;
      });
      final deltaNotifier =
          ref.read(teamFollowersOptimisticDeltaProvider(widget.teamId).notifier);
      deltaNotifier.state += wasFollowing ? -1 : 1;

      final repo = ref.read(teamFollowRepositoryProvider);
      try {
        if (wasFollowing) {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Unfollow?'),
              content: Text('Stop following ${widget.teamName}?'),
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
          if (confirmed != true) {
            deltaNotifier.state += 1;
            setState(() {
              _optimisticFollowing = true;
              _busy = false;
            });
            return;
          }
          await repo.unfollowTeam(teamId: widget.teamId, userId: uid);
        } else {
          await repo.followTeam(teamId: widget.teamId, userId: uid);
        }
        if (mounted) {
          setState(() => _busy = false);
          ref.invalidate(isFollowingTeamProvider(followKey));
          ref.invalidate(teamFollowersCountProvider(widget.teamId));
          ref
              .read(teamFollowersOptimisticDeltaProvider(widget.teamId).notifier)
              .state = 0;
        }
      } catch (e) {
        deltaNotifier.state += wasFollowing ? 1 : -1;
        if (mounted) {
          setState(() {
            _optimisticFollowing = null;
            _busy = false;
          });
          messenger.showSnackBar(
            SnackBar(content: Text('Could not update follow: $e')),
          );
        }
      }
    }

    final label = following ? 'Following' : 'Follow';

    if (widget.compact) {
      if (following) {
        return OutlinedButton.icon(
          onPressed: _busy ? null : toggle,
          icon: const Icon(Icons.check, size: 16),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor: cf.accent,
            side: BorderSide(color: cf.accent),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
        );
      }
      return CfButton(
        label: label,
        compact: true,
        isGold: true,
        isLoading: _busy,
        onPressed: _busy ? null : toggle,
      );
    }

    // Match Share / More header action geometry on the dark hero.
    if (following) {
      return FilledButton.icon(
        onPressed: _busy ? null : toggle,
        icon: _busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.check, size: 17, color: Colors.white),
        label: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.22),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.12),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.75)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }

    return FilledButton.icon(
      onPressed: _busy ? null : toggle,
      icon: _busy
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cf.accent,
              ),
            )
          : Icon(Icons.person_add_alt_1_outlined, size: 17, color: cf.accent),
      label: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: cf.accent,
              fontWeight: FontWeight.w600,
            ),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: cf.accent,
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.45),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
