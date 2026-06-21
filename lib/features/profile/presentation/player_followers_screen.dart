import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../data/models/user_model.dart';
import '../../../shared/providers/player_social_provider.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';
import 'widgets/player_card_tile.dart';

class PlayerFollowersScreen extends ConsumerStatefulWidget {
  const PlayerFollowersScreen({
    super.key,
    required this.playerId,
  });

  final String playerId;

  @override
  ConsumerState<PlayerFollowersScreen> createState() =>
      _PlayerFollowersScreenState();
}

class _PlayerFollowersScreenState extends ConsumerState<PlayerFollowersScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<UserModel> _filter(List<UserModel> users) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return users;
    return users.where((u) {
      final name = u.effectiveName.toLowerCase();
      final id = (u.playerId ?? '').toLowerCase();
      return name.contains(q) || id.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userByPlayerIdProvider(widget.playerId));
    final uid = ref.watch(authStateProvider).value?.uid;

    return Scaffold(
      appBar: CfChromeAppBar(
        title: const Text('Followers'),
        actions: [
          IconButton(
            tooltip: 'Find cricketers',
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/find-cricketers'),
          ),
        ],
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Player not found'));
          }
          final followersAsync = ref.watch(playerFollowersProvider(user.id));
          return Column(
            children: [
              Padding(
                padding: AppDimens.listPadding.copyWith(bottom: 0),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search followers',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              Expanded(
                child: followersAsync.when(
                  data: (followers) {
                    final list = _filter(followers);
                    if (list.isEmpty) {
                      return Center(
                        child: Text(
                          followers.isEmpty
                              ? 'No followers yet'
                              : 'No matches for your search',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: context.cf.textSecondary,
                              ),
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: AppDimens.listPadding,
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final follower = list[index];
                        return PlayerCardTile(
                          user: follower,
                          viewerId: uid,
                          showFollowBack: true,
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('$e')),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}
