import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/providers/player_social_provider.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';
import 'widgets/player_profile_body.dart';

class PlayerPublicProfileScreen extends ConsumerWidget {
  const PlayerPublicProfileScreen({
    super.key,
    required this.playerId,
  });

  final String playerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userByPlayerIdProvider(playerId));
    final viewerId = ref.watch(authStateProvider).value?.uid;

    return Scaffold(
      appBar: CfChromeAppBar(
        title: userAsync.maybeWhen(
          data: (user) => Text(user?.effectiveName ?? 'Player'),
          orElse: () => const Text('Player'),
        ),
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
          final isOwn = viewerId != null && viewerId == user.id;
          return PlayerProfileBody(
            user: user,
            isOwnProfile: isOwn,
            viewerId: viewerId,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}
