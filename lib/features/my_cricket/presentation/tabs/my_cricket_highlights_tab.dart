import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/providers/my_player_provider.dart';
import '../../../../shared/providers/providers.dart';

/// Recent completed matches with quick links to highlights timeline.
class MyCricketHighlightsTab extends ConsumerWidget {
  const MyCricketHighlightsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(matchesProvider);
    final uid = ref.watch(authStateProvider).value?.uid;
    final myPlayer = ref.watch(myPlayerProvider).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: AppColors.surfaceElevated,
          child: ListTile(
            dense: true,
            title: const Text('AI-style highlight moments'),
            subtitle: const Text('Boundaries & wickets from ball-by-ball scoring'),
            trailing: FilledButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Open a completed match → Highlights tab'),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('How it works'),
            ),
          ),
        ),
        Expanded(
          child: matchesAsync.when(
            data: (all) {
              final list = all
                  .where((m) => m.status == MatchStatus.completed)
                  .where((m) {
                    if (uid == null) return true;
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
                padding: const EdgeInsets.all(AppDimens.spaceMd),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final m = list[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: AppDimens.spaceSm),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.primaryBlue,
                        child: Icon(Icons.play_arrow, color: Colors.white),
                      ),
                      title: Text(m.title),
                      subtitle: Text(
                        '${m.teamAName} vs ${m.teamBName}'
                        '${m.scheduledAt != null ? ' · ${AppDateUtils.formatShort(m.scheduledAt!)}' : ''}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          context.push('/match/${m.id}/highlights'),
                    ),
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
  }
}
