import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../data/models/series/series.dart';
import '../../../shared/providers/series_providers.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';
import '../../../domain/services/series/org_competition_access.dart';
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
    final access = ref.watch(orgCompetitionAccessProvider(seriesId));
    final canPropose = access.canStartAnything;

    return Scaffold(
      appBar: CfChromeAppBar(
        title: const Text('Fixtures'),
        actions: [
          if (access.match != OrgStartMode.none)
            IconButton(
              key: const Key('org_start_match'),
              tooltip: OrgCompetitionAccess.actionLabel(
                access.match,
                tournament: false,
              ),
              onPressed: () =>
                  context.push('/series/$seriesId/propose-match'),
              icon: const Icon(Icons.sports_cricket_outlined),
            ),
          if (access.tournament != OrgStartMode.none)
            IconButton(
              key: const Key('org_start_tournament'),
              tooltip: OrgCompetitionAccess.actionLabel(
                access.tournament,
                tournament: true,
              ),
              onPressed: () =>
                  context.push('/series/$seriesId/propose-tournament'),
              icon: const Icon(Icons.emoji_events_outlined),
            ),
          if (access.isOwner)
            IconButton(
              key: const Key('org_request_settings'),
              tooltip: 'Request settings',
              onPressed: () => showOrgCompetitionPolicySheet(
                context,
                ref,
                seriesId: seriesId,
                current: access.policy,
              ),
              icon: const Icon(Icons.tune),
            ),
        ],
      ),
      body: comps.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) => items.isEmpty
            ? SeriesEmptyState(
                icon: Icons.event_outlined,
                title: 'No fixtures yet',
                message: access.isAdmin
                    ? 'Start a match or tournament for this org.'
                    : canPropose
                        ? 'Request a match or tournament. Admins approve it.'
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


/// Owner-only sheet: who may request and whether requests need approval.
Future<void> showOrgCompetitionPolicySheet(
  BuildContext context,
  WidgetRef ref, {
  required String seriesId,
  required OrgCompetitionPolicy current,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _PolicySheet(seriesId: seriesId, initial: current),
  );
}

class _PolicySheet extends ConsumerStatefulWidget {
  const _PolicySheet({required this.seriesId, required this.initial});
  final String seriesId;
  final OrgCompetitionPolicy initial;

  @override
  ConsumerState<_PolicySheet> createState() => _PolicySheetState();
}

class _PolicySheetState extends ConsumerState<_PolicySheet> {
  late OrgCompetitionPolicy _policy = widget.initial;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(seriesFunctionsServiceProvider).updateSeriesCompetitionPolicy(
            seriesId: widget.seriesId,
            policy: _policy.toMap(),
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Match & tournament requests',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppDimens.spaceXs),
            Text(
              'Owner and admins always start directly. These settings apply to '
              'team admins and players.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tournament requests need approval'),
              value: _policy.tournamentRequestsNeedApproval,
              onChanged: (v) => setState(() => _policy =
                  _policy.copyWith(tournamentRequestsNeedApproval: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Match requests need approval'),
              value: _policy.matchRequestsNeedApproval,
              onChanged: (v) => setState(() =>
                  _policy = _policy.copyWith(matchRequestsNeedApproval: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Players can request too'),
              subtitle: const Text('Not just team admins'),
              value: _policy.membersCanRequest,
              onChanged: (v) => setState(
                  () => _policy = _policy.copyWith(membersCanRequest: v)),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
