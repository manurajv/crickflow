import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/user_model.dart';
import '../../../../shared/providers/player_social_provider.dart';
import '../../../profile/presentation/widgets/player_card_tile.dart';

class ProfileConnectionsTab extends ConsumerStatefulWidget {
  const ProfileConnectionsTab({
    super.key,
    required this.userId,
    required this.playerId,
    required this.isOwnProfile,
    this.viewerId,
  });

  final String userId;
  final String playerId;
  final bool isOwnProfile;
  final String? viewerId;

  @override
  ConsumerState<ProfileConnectionsTab> createState() =>
      _ProfileConnectionsTabState();
}

class _ProfileConnectionsTabState extends ConsumerState<ProfileConnectionsTab> {
  _ConnSection _section = _ConnSection.following;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final followers =
        ref.watch(playerFollowersProvider(widget.userId)).valueOrNull ?? [];
    final following =
        ref.watch(playerFollowingProvider(widget.userId)).valueOrNull ?? [];

    final mutuals = widget.isOwnProfile && widget.viewerId != null
        ? _mutuals(followers, following)
        : <UserModel>[];

    var list = switch (_section) {
      _ConnSection.following => following,
      _ConnSection.followers => followers,
      _ConnSection.mutuals => mutuals,
      _ConnSection.search => [...followers, ...following],
    };

    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where(
            (u) =>
                u.effectiveName.toLowerCase().contains(q) ||
                (u.playerId ?? '').toLowerCase().contains(q),
          )
          .toList();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.spaceMd,
            AppDimens.spaceSm,
            AppDimens.spaceMd,
            0,
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search connections',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
            ),
            onChanged: (v) => setState(() => _query = v.trim()),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(AppDimens.spaceSm),
          child: Row(
            children: [
              _chip(cf, 'Following (${following.length})', _ConnSection.following),
              _chip(cf, 'Followers (${followers.length})', _ConnSection.followers),
              if (widget.isOwnProfile)
                _chip(cf, 'Mutuals (${mutuals.length})', _ConnSection.mutuals),
              if (widget.isOwnProfile)
                TextButton.icon(
                  onPressed: () => context.push('/find-cricketers'),
                  icon: const Icon(Icons.person_search_outlined),
                  label: const Text('Find Cricketers'),
                ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Text(
                    _emptyMessage(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cf.textSecondary,
                        ),
                  ),
                )
              : ListView.builder(
                  padding: AppDimens.listPadding,
                  itemCount: list.length,
                  itemBuilder: (_, i) => PlayerCardTile(
                    user: list[i],
                    viewerId: widget.viewerId,
                  ),
                ),
        ),
      ],
    );
  }

  List<UserModel> _mutuals(
    List<UserModel> followers,
    List<UserModel> following,
  ) {
    final followingIds = following.map((u) => u.id).toSet();
    return followers.where((f) => followingIds.contains(f.id)).toList();
  }

  String _emptyMessage() {
    return switch (_section) {
      _ConnSection.following => 'Not following anyone yet.',
      _ConnSection.followers => 'No followers yet.',
      _ConnSection.mutuals => 'No mutual connections yet.',
      _ConnSection.search => 'No results.',
    };
  }

  Widget _chip(CfColors cf, String label, _ConnSection section) {
    final selected = _section == section;
    return Padding(
      padding: const EdgeInsets.only(right: AppDimens.spaceXs),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _section = section),
        selectedColor: cf.accent.withValues(alpha: 0.15),
        checkmarkColor: cf.accent,
      ),
    );
  }
}

enum _ConnSection { following, followers, mutuals, search }
