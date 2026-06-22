import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/user_model.dart';
import '../../../../shared/providers/player_social_provider.dart';
import 'profile_actions_bar.dart';
import 'profile_connections_section.dart';
import 'profile_details_section.dart';
import 'profile_header.dart';

class PlayerProfileBody extends ConsumerStatefulWidget {
  const PlayerProfileBody({
    super.key,
    required this.user,
    required this.isOwnProfile,
    this.viewerId,
  });

  final UserModel user;
  final bool isOwnProfile;
  final String? viewerId;

  @override
  ConsumerState<PlayerProfileBody> createState() => _PlayerProfileBodyState();
}

class _PlayerProfileBodyState extends ConsumerState<PlayerProfileBody> {
  var _recordedView = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _trackView());
  }

  Future<void> _trackView() async {
    if (_recordedView || widget.isOwnProfile) return;
    final viewerId = widget.viewerId;
    if (viewerId == null || viewerId.isEmpty) return;
    _recordedView = true;
    await ref.read(playerFollowRepositoryProvider).recordProfileView(
          profileUserId: widget.user.id,
          viewerUserId: viewerId,
        );
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(playerSocialStatsProvider(widget.user.id));

    return ListView(
      padding: AppDimens.listPadding,
      children: [
        if (widget.isOwnProfile && !widget.user.onboardingCompleted)
          const ProfileOnboardingBanner(),
        ProfileHeader(
          user: widget.user,
          statsOverride: statsAsync.valueOrNull,
        ),
        const SizedBox(height: AppDimens.spaceLg),
        ProfileActionsBar(
          user: widget.user,
          isOwnProfile: widget.isOwnProfile,
          viewerId: widget.viewerId,
        ),
        const SizedBox(height: AppDimens.spaceXl),
        ProfileDetailsSection(
          user: widget.user,
          isOwnProfile: widget.isOwnProfile,
        ),
        const SizedBox(height: AppDimens.spaceXl),
        ProfileConnectionsSection(
          user: widget.user,
          isOwnProfile: widget.isOwnProfile,
          viewerId: widget.viewerId,
        ),
        const SizedBox(height: AppDimens.spaceMd),
        Center(
          child: OutlinedButton.icon(
            onPressed: () {
              final id = widget.user.playerId;
              if (id == null || id.isEmpty) {
                context.push('/my-cricket-profile');
              } else {
                context.push('/player/$id/cricket');
              }
            },
            icon: const Icon(Icons.sports_cricket),
            label: const Text('Open Cricket Profile'),
          ),
        ),
        const SizedBox(height: AppDimens.spaceXl),
      ],
    );
  }
}
