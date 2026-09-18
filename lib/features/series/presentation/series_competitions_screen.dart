import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../data/models/series/series.dart';
import '../../../shared/providers/series_providers.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';
import 'widgets/series_ui.dart';

class SeriesCompetitionsScreen extends ConsumerWidget {
  const SeriesCompetitionsScreen({super.key, required this.seriesId});
  final String seriesId;

  String _clubName(
    String? clubId,
    List<SeriesClubModel> clubs,
  ) {
    if (clubId == null || clubId.isEmpty) return '';
    for (final c in clubs) {
      if (c.id == clubId) return c.name;
    }
    return '';
  }

  String _titleFor(
    SeriesCompetitionModel c,
    List<SeriesClubModel> clubs,
  ) {
    final titled = c.title.trim();
    if (titled.isNotEmpty) return titled;

    final a = _clubName(c.clubAId, clubs);
    final b = _clubName(c.clubBId, clubs);
    if (a.isNotEmpty && b.isNotEmpty) return '$a vs $b';
    if (a.isNotEmpty) return a;
    if (b.isNotEmpty) return b;

    return c.type == SeriesCompetitionType.tournament
        ? 'Tournament fixture'
        : 'Match fixture';
  }

  String _subtitleFor(SeriesCompetitionModel c) {
    final parts = <String>[
      c.type.label,
      c.status.label,
    ];
    if (c.isOfficial) parts.add('Official');
    if (c.matchId != null && c.matchId!.isNotEmpty) {
      parts.add('Open match');
    } else if (c.tournamentId != null && c.tournamentId!.isNotEmpty) {
      parts.add('Open tournament');
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comps = ref.watch(seriesCompetitionsProvider(seriesId));
    final clubs = ref.watch(clubsForSeriesProvider(seriesId)).valueOrNull ??
        const <SeriesClubModel>[];
    final role = ref.watch(mySeriesRoleProvider(seriesId));
    final canPropose = role == SeriesRole.superAdmin ||
        role == SeriesRole.seriesAdmin ||
        role == SeriesRole.clubAdmin;

    return Scaffold(
      appBar: CfChromeAppBar(
        title: const Text('Fixtures'),
        actions: [
          if (canPropose) ...[
            IconButton(
              tooltip: 'Propose match',
              onPressed: () =>
                  context.push('/series/$seriesId/propose-match'),
              icon: const Icon(Icons.sports_cricket_outlined),
            ),
            IconButton(
              tooltip: 'Propose tournament',
              onPressed: () =>
                  context.push('/series/$seriesId/propose-tournament'),
              icon: const Icon(Icons.emoji_events_outlined),
            ),
          ],
        ],
      ),
      body: comps.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) => items.isEmpty
            ? SeriesEmptyState(
                icon: Icons.event_outlined,
                title: 'No fixtures yet',
                message: canPropose
                    ? 'Propose a match or tournament for approval.'
                    : 'Approved fixtures will appear here.',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(AppDimens.spaceMd),
                itemCount: items.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppDimens.spaceSm),
                itemBuilder: (_, i) {
                  final c = items[i];
                  final canOpen = (c.matchId != null && c.matchId!.isNotEmpty) ||
                      (c.tournamentId != null && c.tournamentId!.isNotEmpty);
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        c.type == SeriesCompetitionType.tournament
                            ? Icons.emoji_events_outlined
                            : Icons.sports_cricket_outlined,
                        color: AppColors.gold,
                      ),
                      title: Text(_titleFor(c, clubs)),
                      subtitle: Text(_subtitleFor(c)),
                      trailing: c.isOfficial
                          ? const Icon(Icons.verified, color: AppColors.gold)
                          : canOpen
                              ? const Icon(Icons.chevron_right)
                              : null,
                      onTap: !canOpen
                          ? null
                          : () {
                              if (c.matchId != null && c.matchId!.isNotEmpty) {
                                context.push('/match/${c.matchId}');
                              } else if (c.tournamentId != null &&
                                  c.tournamentId!.isNotEmpty) {
                                context.push('/tournaments/${c.tournamentId}');
                              }
                            },
                    ),
                  );
                },
              ),
      ),
    );
  }
}
