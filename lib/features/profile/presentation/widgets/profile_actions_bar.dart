import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../core/utils/deep_link_utils.dart';
import '../../../../data/models/user_model.dart';
import '../../../../shared/widgets/cf_button.dart';
import 'player_follow_button.dart';

class ProfileActionsBar extends ConsumerWidget {
  const ProfileActionsBar({
    super.key,
    required this.user,
    required this.isOwnProfile,
    this.viewerId,
  });

  final UserModel user;
  final bool isOwnProfile;
  final String? viewerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isOwnProfile) {
      return Wrap(
        spacing: AppDimens.spaceSm,
        runSpacing: AppDimens.spaceSm,
        alignment: WrapAlignment.center,
        children: [
          CfButton(
            label: 'Share Profile',
            compact: true,
            isOutlined: true,
            onPressed: () => _shareProfile(user),
          ),
          CfButton(
            label: 'QR Code',
            compact: true,
            isOutlined: true,
            onPressed: () {
              final id = user.playerId;
              if (id == null || id.isEmpty) return;
              context.push('/player/$id/qr');
            },
          ),
          CfButton(
            label: 'Settings',
            compact: true,
            isOutlined: true,
            onPressed: () => context.push('/settings'),
          ),
        ],
      );
    }

    return Column(
      children: [
        if (viewerId != null && viewerId != user.id)
          PlayerFollowButton(
            followedUser: user,
            followerUserId: viewerId!,
          ),
        const SizedBox(height: AppDimens.spaceSm),
        Wrap(
          spacing: AppDimens.spaceSm,
          runSpacing: AppDimens.spaceSm,
          alignment: WrapAlignment.center,
          children: [
            CfButton(
              label: 'Share',
              compact: true,
              isOutlined: true,
              onPressed: () => _shareProfile(user),
            ),
            CfButton(
              label: 'Message',
              compact: true,
              isOutlined: true,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Messaging coming soon')),
                );
              },
            ),
            CfButton(
              label: 'Report Player',
              compact: true,
              isOutlined: true,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report player coming soon')),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  static Future<void> _shareProfile(UserModel user) async {
    final playerId = user.playerId;
    if (playerId == null || playerId.isEmpty) return;
    final appLink = DeepLinkUtils.playerUri(playerId).toString();
    final webLink = DeepLinkUtils.hostedPlayerUri(playerId).toString();
    await Share.share(
      'Check out ${user.effectiveName} on CrickFlow ($playerId)\n$appLink\n$webLink',
    );
  }
}

class ProfileOnboardingBanner extends StatelessWidget {
  const ProfileOnboardingBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimens.spaceMd),
      color: cf.accent.withValues(alpha: 0.12),
      child: ListTile(
        leading: Icon(Icons.info_outline, color: cf.accent),
        title: const Text('Complete your player profile'),
        subtitle: const Text('Required before scoring or managing teams'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/player-onboarding'),
      ),
    );
  }
}
