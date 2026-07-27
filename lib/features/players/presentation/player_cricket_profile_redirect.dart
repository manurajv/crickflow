import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/providers/badge_provider.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';
import '../../teams/presentation/utils/team_squad_utils.dart';

/// Legacy `/players/:id` entry — redirects to the user (social) profile when possible.
class PlayerCricketProfileRedirect extends ConsumerStatefulWidget {
  const PlayerCricketProfileRedirect({super.key, required this.playerDocId});

  final String playerDocId;

  @override
  ConsumerState<PlayerCricketProfileRedirect> createState() =>
      _PlayerCricketProfileRedirectState();
}

class _PlayerCricketProfileRedirectState
    extends ConsumerState<PlayerCricketProfileRedirect> {
  var _redirected = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(playerDetailProvider(widget.playerDocId));

    return async.when(
      loading: () => const Scaffold(
        appBar: CfChromeAppBar(title: Text('Player')),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: const CfChromeAppBar(title: Text('Player')),
        body: Center(child: Text('$e')),
      ),
      data: (player) {
        final path =
            player == null ? null : TeamSquadUtils.userProfilePath(player);
        if (path != null && !_redirected) {
          _redirected = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            context.replace(path);
          });
          return const Scaffold(
            appBar: CfChromeAppBar(title: Text('Player')),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: const CfChromeAppBar(title: Text('Player')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                player == null
                    ? 'Player not found'
                    : 'No profile for this player.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }
}
