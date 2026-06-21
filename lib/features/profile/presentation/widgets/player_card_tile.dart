import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../core/utils/player_profile_labels.dart';
import '../../../../data/models/user_model.dart';
import '../../../../shared/providers/providers.dart';
import 'player_follow_button.dart';

class PlayerCardTile extends ConsumerWidget {
  const PlayerCardTile({
    super.key,
    required this.user,
    this.viewerId,
    this.showFollowBack = false,
    this.onOpenProfile,
  });

  final UserModel user;
  final String? viewerId;
  final bool showFollowBack;
  final VoidCallback? onOpenProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final currentUid = viewerId ?? ref.watch(authStateProvider).value?.uid;

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: cfCardDecoration(context),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: CfColors.primaryBlue,
            backgroundImage:
                user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
            child: user.photoUrl == null
                ? Text(
                    user.effectiveName.isNotEmpty
                        ? user.effectiveName[0].toUpperCase()
                        : '?',
                    style: TextStyle(color: cf.onPrimary),
                  )
                : null,
          ),
          const SizedBox(width: AppDimens.spaceMd),
          Expanded(
            child: InkWell(
              onTap: onOpenProfile ??
                  () {
                    final id = user.playerId;
                    if (id != null && id.isNotEmpty) {
                      context.push('/player/$id');
                    }
                  },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.effectiveName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cf.textPrimary,
                        ),
                  ),
                  if (user.playerId != null && user.playerId!.isNotEmpty)
                    Text(
                      user.playerId!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cf.textSecondary,
                          ),
                    ),
                  Text(
                    PlayerProfileLabels.playingRole(user),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cf.textSecondary,
                        ),
                  ),
                  Text(
                    PlayerProfileLabels.location(user),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cf.textMuted,
                        ),
                  ),
                ],
              ),
            ),
          ),
          if (currentUid != null &&
              currentUid.isNotEmpty &&
              currentUid != user.id)
            PlayerFollowButton(
              followedUser: user,
              followerUserId: currentUid,
              compact: true,
              showFollowBack: showFollowBack,
            ),
        ],
      ),
    );
  }
}
