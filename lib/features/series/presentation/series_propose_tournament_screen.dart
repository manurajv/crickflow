import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../data/models/series/series.dart';
import '../../../domain/services/series/org_competition_access.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/series_providers.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';
import '../../../shared/widgets/start_match_ui.dart';
import 'widgets/series_ui.dart';

/// Teams picked for an org tournament before the creation wizard runs.
/// Read (and cleared) by the wizard once the tournament exists.
final orgTournamentTeamsProvider =
    StateProvider<({String seriesId, List<String> teamIds})?>((_) => null);

/// Start (admins) or request (team admins / allowed members) a tournament in
/// an org. Picks org teams, then runs the normal tournament wizard.
class SeriesProposeTournamentScreen extends ConsumerStatefulWidget {
  const SeriesProposeTournamentScreen({
    super.key,
    required this.seriesId,
    this.clubId,
  });

  final String seriesId;
  final String? clubId;

  @override
  ConsumerState<SeriesProposeTournamentScreen> createState() =>
      _SeriesProposeTournamentScreenState();
}

class _SeriesProposeTournamentScreenState
    extends ConsumerState<SeriesProposeTournamentScreen> {
  final Set<String> _selected = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.clubId != null) _selected.add(widget.clubId!);
  }

  void _continue() {
    ref.read(orgTournamentTeamsProvider.notifier).state = (
      seriesId: widget.seriesId,
      teamIds: _selected.toList(),
    );
    context.push('/tournaments/create?seriesId=${widget.seriesId}');
  }

  Future<void> _linkExisting(String tournamentId, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add tournament to org?'),
        content: Text(
          '"$name" becomes an official org tournament'
          '${_selected.isEmpty ? '' : ' and the selected teams are added to it'}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final res = await ref.read(seriesFunctionsServiceProvider).startSeriesTournament(
            seriesId: widget.seriesId,
            tournamentId: tournamentId,
            teamClubIds: _selected.toList(),
            title: name,
            linkExisting: true,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            OrgCompetitionAccess.outcomeMessage(
              autoApproved: res['autoApproved'] == true,
              tournament: true,
            ),
          ),
        ),
      );
      context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not add: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(orgCompetitionAccessProvider(widget.seriesId));
    final mode = access.tournament;
    final teamsAsync = ref.watch(clubsForSeriesProvider(widget.seriesId));

    return Scaffold(
      appBar: CfChromeAppBar(
        title: Text(OrgCompetitionAccess.actionLabel(mode, tournament: true)),
      ),
      body: mode == OrgStartMode.none
          ? const SeriesEmptyState(
              icon: Icons.lock_outline,
              title: 'No access',
              message: 'Only org admins and team admins of org teams can start '
                  'tournaments here.',
            )
          : teamsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (all) {
                final teams = playableOrgTeams(all);
                return ListView(
                  padding: const EdgeInsets.all(AppDimens.spaceLg),
                  children: [
                    StartMatchInfoBanner(
                      message: switch (mode) {
                        OrgStartMode.direct =>
                          'As an org admin, the tournament is added to the org straight away.',
                        OrgStartMode.requestAutoApproved =>
                          'Your tournament is added to the org straight away.',
                        _ =>
                          'You create the tournament as usual. It becomes an official org tournament once an admin approves it.',
                      },
                    ),
                    const SizedBox(height: AppDimens.spaceLg),
                    Text(
                      'Teams',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppDimens.spaceXs),
                    Text(
                      teams.isEmpty
                          ? 'No org teams are linked to a CrickFlow team yet. You can add teams later from the tournament.'
                          : 'Pick the org teams to add. You can add more later.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    for (final t in teams)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _selected.contains(t.id),
                        title: Text(t.name),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selected.add(t.id);
                          } else {
                            _selected.remove(t.id);
                          }
                        }),
                      ),
                    const SizedBox(height: AppDimens.spaceLg),
                    FilledButton.icon(
                      key: const Key('org_tournament_continue'),
                      onPressed: _busy ? null : _continue,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Continue to tournament setup'),
                    ),
                    if (access.isAdmin) ...[
                      const SizedBox(height: AppDimens.spaceLg),
                      _ExistingTournaments(
                        seriesId: widget.seriesId,
                        enabled: !_busy,
                        onPick: _linkExisting,
                      ),
                    ],
                  ],
                );
              },
            ),
    );
  }
}

/// Admin-only: add one of your own existing tournaments (no ID typing).
class _ExistingTournaments extends ConsumerWidget {
  const _ExistingTournaments({
    required this.seriesId,
    required this.enabled,
    required this.onPick,
  });

  final String seriesId;
  final bool enabled;
  final void Function(String id, String name) onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(myOrganizedTournamentsProvider).valueOrNull ?? const [];
    final linkable = mine
        .where((t) =>
            (t.seriesId ?? '').isEmpty ||
            t.seriesOfficialStatus == SeriesOfficialStatus.rejected.name)
        .toList();
    return ExpansionTile(
      key: const Key('org_link_existing'),
      tilePadding: EdgeInsets.zero,
      title: const Text('Add one of your existing tournaments'),
      children: [
        if (linkable.isEmpty)
          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('No tournaments of yours to add'),
          ),
        for (final t in linkable.take(30))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.emoji_events_outlined),
            title: Text(t.name),
            trailing: const Icon(Icons.add),
            enabled: enabled,
            onTap: () => onPick(t.id, t.name),
          ),
      ],
    );
  }
}
