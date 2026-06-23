import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_dimens.dart';
import '../../../../../data/models/tournament_model.dart';
import '../../../../../domain/services/auto_fixture_generator_service.dart';
import '../../../../../shared/providers/providers.dart';
import '../../../../../shared/providers/tournament_match_providers.dart';
import '../../../../../shared/widgets/cf_button.dart';

Future<void> showAutoFixtureSheet({
  required BuildContext context,
  required TournamentModel tournament,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    builder: (_) => _AutoFixtureSheet(tournament: tournament),
  );
}

class _AutoFixtureSheet extends ConsumerStatefulWidget {
  const _AutoFixtureSheet({required this.tournament});

  final TournamentModel tournament;

  @override
  ConsumerState<_AutoFixtureSheet> createState() => _AutoFixtureSheetState();
}

class _AutoFixtureSheetState extends ConsumerState<_AutoFixtureSheet> {
  AutoFixtureMode _mode = AutoFixtureMode.league;
  String? _roundId;
  var _busy = false;

  @override
  Widget build(BuildContext context) {
    final rounds =
        ref.watch(tournamentActiveRoundsProvider(widget.tournament.id));
    final uid = ref.watch(authStateProvider).value?.uid;

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
            'Auto generate fixtures',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          DropdownButtonFormField<AutoFixtureMode>(
            value: _mode,
            decoration: const InputDecoration(
              labelText: 'Format',
              border: OutlineInputBorder(),
            ),
            items: AutoFixtureMode.values
                .map(
                  (m) => DropdownMenuItem(
                    value: m,
                    child: Text(m.label),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _mode = v ?? _mode),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            _mode.description,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (rounds.isNotEmpty) ...[
            const SizedBox(height: AppDimens.spaceMd),
            DropdownButtonFormField<String?>(
              value: _roundId,
              decoration: const InputDecoration(
                labelText: 'Round (optional)',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('No round')),
                ...rounds.map(
                  (r) => DropdownMenuItem(value: r.id, child: Text(r.name)),
                ),
              ],
              onChanged: (v) => setState(() => _roundId = v),
            ),
          ],
          const SizedBox(height: AppDimens.spaceLg),
          CfButton(
            label: 'Generate fixtures',
            isGold: true,
            isLoading: _busy,
            onPressed: _busy || uid == null
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      final repo = ref.read(tournamentRepositoryProvider);
                      final service =
                          ref.read(autoFixtureGeneratorServiceProvider);
                      final round = rounds
                          .where((r) => r.id == _roundId)
                          .firstOrNull;
                      final ids = await service.generateByMode(
                        repository: repo,
                        tournamentId: widget.tournament.id,
                        createdBy: uid,
                        mode: _mode,
                        roundId: _roundId,
                        roundName: round?.name,
                      );
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Created ${ids.length} matches'),
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$e')),
                      );
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
          ),
        ],
      ),
    );
  }
}
