import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../shared/providers/my_player_provider.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/match_list_card.dart';
import '../widgets/my_cricket_action_banner.dart';
import '../widgets/my_cricket_guest_sign_in_prompt.dart';

/// Recent completed matches with quick links to highlights timeline.
class MyCricketHighlightsTab extends ConsumerWidget {
  const MyCricketHighlightsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).value?.uid;
    if (uid == null) {
      return const MyCricketGuestSignInPrompt(
        title: 'Sign in to view your highlights',
        subtitle:
            'Sign in with a CrickFlow account to see highlight moments from '
            'your completed matches.',
      );
    }

    final matchesAsync = ref.watch(matchesProvider);
    final myPlayer = ref.watch(myPlayerProvider).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MyCricketActionBanner(
          title: 'AI-style highlight moments',
          subtitle: 'Boundaries & wickets from ball-by-ball scoring',
          actionLabel: 'How it works',
          onAction: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Open a completed match → Highlights tab'),
              ),
            );
          },
        ),
        Expanded(
          child: matchesAsync.when(
            data: (all) {
              final list = all
                  .where((m) => m.status == MatchStatus.completed)
                  .where((m) {
                    if (m.createdBy == uid || m.scorerIds.contains(uid)) {
                      return true;
                    }
                    if (myPlayer != null) {
                      return myPlayer.effectiveTeamIds.any(
                        (id) => m.teamAId == id || m.teamBId == id,
                      );
                    }
                    return false;
                  })
                  .take(20)
                  .toList();

              if (list.isEmpty) {
                return const Center(
                  child: Text('Complete a match to see highlights here'),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
                itemCount: list.length,
                itemBuilder: (_, i) => MatchListCard(
                  match: list[i],
                  showTournamentHeader: false,
                ),
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
          ),
        ),
      ],
    );
  }
}
