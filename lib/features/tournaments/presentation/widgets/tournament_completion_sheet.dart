import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/tournament_model.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/providers/tournament_analytics_providers.dart';
import '../../../../shared/widgets/cf_button.dart';

Future<void> showTournamentCompletionSheet(
  BuildContext context,
  WidgetRef ref, {
  required TournamentModel tournament,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _TournamentCompletionSheet(
      tournament: tournament,
      ref: ref,
    ),
  );
}

class _TournamentCompletionSheet extends ConsumerStatefulWidget {
  const _TournamentCompletionSheet({
    required this.tournament,
    required this.ref,
  });

  final TournamentModel tournament;
  final WidgetRef ref;

  @override
  ConsumerState<_TournamentCompletionSheet> createState() =>
      _TournamentCompletionSheetState();
}

class _TournamentCompletionSheetState
    extends ConsumerState<_TournamentCompletionSheet> {
  String? _championId;
  String? _runnerUpId;
  String? _thirdPlaceId;
  var _saving = false;

  @override
  Widget build(BuildContext context) {
    final heroes =
        ref.watch(tournamentHeroesProvider(widget.tournament.id)).valueOrNull;
    final teams = widget.tournament.teamIds;

    return Padding(
      padding: EdgeInsets.only(
        left: AppDimens.spaceMd,
        right: AppDimens.spaceMd,
        top: AppDimens.spaceMd,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppDimens.spaceMd,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Finish tournament',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppDimens.spaceSm),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Champion'),
            items: teams
                .map((id) => DropdownMenuItem(value: id, child: Text(id)))
                .toList(),
            onChanged: (v) => setState(() => _championId = v),
          ),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Runner-up'),
            items: teams
                .where((id) => id != _championId)
                .map((id) => DropdownMenuItem(value: id, child: Text(id)))
                .toList(),
            onChanged: (v) => setState(() => _runnerUpId = v),
          ),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Third place (optional)'),
            items: teams
                .where((id) => id != _championId && id != _runnerUpId)
                .map((id) => DropdownMenuItem(value: id, child: Text(id)))
                .toList(),
            onChanged: (v) => setState(() => _thirdPlaceId = v),
          ),
          if (heroes != null && heroes.hasData) ...[
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              'Awards auto-filled from Heroes tab',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppDimens.spaceMd),
          CfButton(
            label: 'Complete tournament',
            isGold: true,
            isLoading: _saving,
            onPressed: _championId == null || _saving ? null : _finish,
          ),
        ],
      ),
    );
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      final heroes = await widget.ref
          .read(tournamentHeroesProvider(widget.tournament.id).future);
      final awards = <String, String>{};
      for (final h in heroes.heroes) {
        awards[h.award.name] = h.playerId;
      }

      await widget.ref.read(tournamentRepositoryProvider).completeTournament(
            tournamentId: widget.tournament.id,
            championTeamId: _championId!,
            championTeamName: _championId!,
            runnerUpTeamId: _runnerUpId,
            runnerUpTeamName: _runnerUpId,
            thirdPlaceTeamId: _thirdPlaceId,
            awards: awards,
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tournament completed — teams have been notified'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
