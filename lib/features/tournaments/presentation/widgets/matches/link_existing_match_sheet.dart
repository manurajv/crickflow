import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/cf_colors.dart';
import '../../../../../data/models/match_model.dart';
import '../../../../../data/models/tournament_model.dart';
import '../../../../../data/services/tournament_functions_service.dart';
import '../../../../../domain/services/tournament/tournament_match_link_policy.dart';
import '../../../../../shared/providers/providers.dart';
import '../../../../../shared/providers/tournament_providers.dart';

/// Tournament admins: add an existing normal/quick match between tournament
/// teams. Linking is validated by the `linkMatchToTournament` callable, which
/// also recalculates standings for finished matches.
Future<void> showLinkExistingMatchSheet({
  required BuildContext context,
  required TournamentModel tournament,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    builder: (_) => _LinkExistingMatchSheet(tournament: tournament),
  );
}

final _linkCandidatesProvider = FutureProvider.autoDispose
    .family<List<MatchModel>, TournamentModel>((ref, tournament) async {
  final matches = await ref
      .read(matchRepositoryProvider)
      .fetchMatchesForTeams(tournament.teamIds);
  return TournamentMatchLinkPolicy.linkable(
    matches,
    tournament.teamIds,
    orgTournament: isOrgTournament(tournament),
  );
});

class _LinkExistingMatchSheet extends ConsumerStatefulWidget {
  const _LinkExistingMatchSheet({required this.tournament});

  final TournamentModel tournament;

  @override
  ConsumerState<_LinkExistingMatchSheet> createState() =>
      _LinkExistingMatchSheetState();
}

class _LinkExistingMatchSheetState
    extends ConsumerState<_LinkExistingMatchSheet> {
  String? _linkingId;

  Future<void> _link(MatchModel match) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add match to tournament?'),
        content: Text(
          '${match.teamAName} vs ${match.teamBName} will count in '
          '${widget.tournament.name} fixtures and standings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add match'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _linkingId = match.id);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final standingsUpdated = await ref
          .read(tournamentFunctionsServiceProvider)
          .linkMatchToTournament(
            tournamentId: widget.tournament.id,
            matchId: match.id,
          );
      ref.invalidate(tournamentMatchesProvider(widget.tournament.id));
      ref.invalidate(tournamentProvider(widget.tournament.id));
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            standingsUpdated
                ? 'Match added — standings updated.'
                : 'Match added to the tournament.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _linkingId = null);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Could not add match: ${TournamentFunctionsService.messageFor(e)}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final theme = Theme.of(context);
    final candidates = ref.watch(_linkCandidatesProvider(widget.tournament));

    return Padding(
      padding: AppDimens.screenPadding,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add existing match',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              'Normal or quick matches between teams in this tournament that '
              'are not linked to another tournament.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cf.textSecondary,
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Flexible(
              child: candidates.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppDimens.spaceLg),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text('Could not load matches: $e'),
                data: (list) {
                  if (list.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(AppDimens.spaceLg),
                      child: Text(
                        'No matches found between tournament teams.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cf.textSecondary,
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: list.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppDimens.spaceSm),
                    itemBuilder: (_, i) => _CandidateTile(
                      match: list[i],
                      busy: _linkingId == list[i].id,
                      enabled: _linkingId == null,
                      onTap: () => _link(list[i]),
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              height: MediaQuery.paddingOf(context).bottom + AppDimens.spaceMd,
            ),
          ],
        ),
      ),
    );
  }
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({
    required this.match,
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  final MatchModel match;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final date = match.completedAt ?? match.scheduledAt ?? match.createdAt;
    final subtitle = [
      if (match.isQuickMatch) 'Quick match' else 'Normal match',
      match.status.name[0].toUpperCase() + match.status.name.substring(1),
      if (date != null) DateFormat.yMMMd().format(date.toLocal()),
    ].join(' · ');
    return Material(
      color: cf.surfaceElevated,
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        enabled: enabled,
        onTap: onTap,
        title: Text(
          '${match.teamAName} vs ${match.teamBName}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          match.resultSummary.trim().isNotEmpty
              ? '$subtitle\n${match.resultSummary.trim()}'
              : subtitle,
        ),
        isThreeLine: match.resultSummary.trim().isNotEmpty,
        trailing: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(Icons.add_circle_outline, color: cf.accent),
      ),
    );
  }
}
