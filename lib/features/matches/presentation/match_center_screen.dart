import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/match_model.dart';
import '../../../shared/providers/providers.dart';
import 'match_hub_screen.dart';

/// Opens the multi-tab match hub (Summary · Scorecard · Comms · …).
class MatchCenterScreen extends ConsumerWidget {
  const MatchCenterScreen({super.key, required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MatchHubScreen(matchId: matchId);
  }
}

Future<void> openFantasyForMatch(
  BuildContext context,
  WidgetRef ref,
  MatchModel match,
  bool canManage,
) async {
  if (!canManage) {
    context.push('/fantasy');
    return;
  }

  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Create fantasy league'),
            onTap: () => Navigator.pop(ctx, 'create'),
          ),
          ListTile(
            leading: const Icon(Icons.vpn_key),
            title: const Text('Join with code'),
            onTap: () => Navigator.pop(ctx, 'join'),
          ),
          ListTile(
            leading: const Icon(Icons.list),
            title: const Text('My fantasy leagues'),
            onTap: () => Navigator.pop(ctx, 'list'),
          ),
        ],
      ),
    ),
  );

  if (!context.mounted) return;

  if (action == 'create') {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    final leagueId =
        await ref.read(fantasyRepositoryProvider).createLeagueForMatch(
              match: match,
              createdBy: uid,
            );
    if (context.mounted) context.push('/fantasy/$leagueId');
  } else if (action == 'join' || action == 'list') {
    context.push('/fantasy');
  }
}
