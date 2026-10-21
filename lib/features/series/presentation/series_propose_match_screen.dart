import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/enums.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../data/models/series/series.dart';
import '../../../domain/services/series/org_competition_access.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/series_providers.dart';
import '../../../shared/providers/start_match_draft_provider.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';
import '../../../shared/widgets/start_match_ui.dart';
import 'widgets/series_ui.dart';

/// Start (admins) or request (team admins / allowed members) a match between
/// two org teams, then continue into the normal or quick match setup.
class SeriesProposeMatchScreen extends ConsumerStatefulWidget {
  const SeriesProposeMatchScreen({
    super.key,
    required this.seriesId,
    this.clubId,
  });

  final String seriesId;

  /// Pre-selects this org team as Team A.
  final String? clubId;

  @override
  ConsumerState<SeriesProposeMatchScreen> createState() =>
      _SeriesProposeMatchScreenState();
}

class _SeriesProposeMatchScreenState
    extends ConsumerState<SeriesProposeMatchScreen> {
  String? _teamAId;
  String? _teamBId;
  String? _tournamentId;
  MatchMode _mode = MatchMode.normal;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _teamAId = widget.clubId;
  }

  Future<void> _continue(
    OrgCompetitionAccess access,
    List<SeriesClubModel> teams,
  ) async {
    final error = access.matchTeamsError(_teamAId, _teamBId);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    final a = teams.firstWhere((t) => t.id == _teamAId);
    final b = teams.firstWhere((t) => t.id == _teamBId);
    setState(() => _busy = true);
    try {
      final repo = ref.read(teamRepositoryProvider);
      final teamA = await repo.getTeam(a.linkedTeamId!);
      final teamB = await repo.getTeam(b.linkedTeamId!);
      if (!mounted) return;
      if (teamA == null || teamB == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load the teams. Try again.')),
        );
        return;
      }
      ref.read(startMatchDraftProvider.notifier)
        ..reset(
          mode: _mode,
          tournamentId: _tournamentId,
          seriesId: widget.seriesId,
          seriesTeamIds: teams.map((t) => t.linkedTeamId!).toList(),
        )
        ..setTeamA(teamA)
        ..setTeamB(teamB);
      context.push(_mode == MatchMode.quick ? '/match/quick' : '/match/create');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not continue: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(orgCompetitionAccessProvider(widget.seriesId));
    final teamsAsync = ref.watch(clubsForSeriesProvider(widget.seriesId));
    final comps =
        ref.watch(seriesCompetitionsProvider(widget.seriesId)).valueOrNull ??
            const <SeriesCompetitionModel>[];
    final orgTournaments = comps
        .where((c) =>
            c.type == SeriesCompetitionType.tournament &&
            c.status == SeriesOfficialStatus.approved &&
            (c.tournamentId ?? '').isNotEmpty)
        .toList();
    final mode = access.match;

    return Scaffold(
      appBar: CfChromeAppBar(
        title: Text(
          OrgCompetitionAccess.actionLabel(mode, tournament: false),
        ),
      ),
      body: mode == OrgStartMode.none
          ? const SeriesEmptyState(
              icon: Icons.lock_outline,
              title: 'No access',
              message: 'Only org admins and team admins of org teams can start '
                  'matches here.',
            )
          : teamsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (all) {
                final teams = playableOrgTeams(all);
                final unlinked = all
                    .where((t) =>
                        t.status == SeriesClubStatus.approved &&
                        (t.linkedTeamId ?? '').isEmpty)
                    .toList();
                if (teams.length < 2) {
                  return SeriesEmptyState(
                    icon: Icons.groups_outlined,
                    title: 'Need two playable teams',
                    message: 'An org match needs two approved teams linked to '
                        'a CrickFlow team.'
                        '${unlinked.isEmpty ? '' : ' Not linked yet: ${unlinked.map((t) => t.name).join(', ')}.'}',
                  );
                }
                final validA =
                    teams.any((t) => t.id == _teamAId) ? _teamAId : null;
                final validB =
                    teams.any((t) => t.id == _teamBId) ? _teamBId : null;
                return ListView(
                  padding: const EdgeInsets.all(AppDimens.spaceLg),
                  children: [
                    StartMatchInfoBanner(
                      message: switch (mode) {
                        OrgStartMode.direct =>
                          'As an org admin, the match is added to the org straight away.',
                        OrgStartMode.requestAutoApproved =>
                          'Your match is added to the org straight away. One of the teams must be yours.',
                        _ =>
                          'You can set up and play the match now. It counts for the org once an admin approves it. One of the teams must be yours.',
                      },
                    ),
                    const SizedBox(height: AppDimens.spaceLg),
                    DropdownButtonFormField<String>(
                      key: const Key('org_match_team_a'),
                      // ignore: deprecated_member_use
                      value: validA,
                      decoration: const InputDecoration(labelText: 'Team A'),
                      items: [
                        for (final t in teams)
                          DropdownMenuItem(value: t.id, child: Text(t.name)),
                      ],
                      onChanged: (v) => setState(() => _teamAId = v),
                    ),
                    const SizedBox(height: AppDimens.spaceMd),
                    DropdownButtonFormField<String>(
                      key: const Key('org_match_team_b'),
                      // ignore: deprecated_member_use
                      value: validB,
                      decoration: const InputDecoration(labelText: 'Team B'),
                      items: [
                        for (final t in teams)
                          DropdownMenuItem(value: t.id, child: Text(t.name)),
                      ],
                      onChanged: (v) => setState(() => _teamBId = v),
                    ),
                    if (orgTournaments.isNotEmpty) ...[
                      const SizedBox(height: AppDimens.spaceMd),
                      DropdownButtonFormField<String?>(
                        // ignore: deprecated_member_use
                        value: _tournamentId,
                        decoration: const InputDecoration(
                          labelText: 'Org tournament (optional)',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Not part of a tournament'),
                          ),
                          for (final c in orgTournaments)
                            DropdownMenuItem<String?>(
                              value: c.tournamentId,
                              child: Text(c.title.isEmpty ? 'Tournament' : c.title),
                            ),
                        ],
                        onChanged: (v) => setState(() => _tournamentId = v),
                      ),
                    ],
                    const SizedBox(height: AppDimens.spaceLg),
                    SegmentedButton<MatchMode>(
                      segments: const [
                        ButtonSegment(
                          value: MatchMode.normal,
                          label: Text('Normal match'),
                        ),
                        ButtonSegment(
                          value: MatchMode.quick,
                          label: Text('Quick match'),
                        ),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (s) =>
                          setState(() => _mode = s.first),
                    ),
                    if (unlinked.isNotEmpty) ...[
                      const SizedBox(height: AppDimens.spaceMd),
                      Text(
                        'Not linked to a CrickFlow team yet, so they cannot play: '
                        '${unlinked.map((t) => t.name).join(', ')}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: AppDimens.spaceLg),
                    FilledButton.icon(
                      key: const Key('org_match_continue'),
                      onPressed: _busy ? null : () => _continue(access, teams),
                      icon: _busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_forward),
                      label: const Text('Continue to match setup'),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
