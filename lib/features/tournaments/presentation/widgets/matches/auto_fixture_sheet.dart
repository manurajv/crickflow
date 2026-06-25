import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/cf_colors.dart';
import '../../../../../data/models/tournament_model.dart';
import '../../../../../domain/services/auto_fixture_generator_service.dart';
import '../../../../../shared/providers/providers.dart';
import '../../../../../shared/providers/tournament_match_providers.dart';
import '../../../../../shared/widgets/cf_button.dart';
import '../../utils/tournament_display_utils.dart';
import '../../utils/tournament_format_utils.dart';

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
  late AutoFixtureMode _mode;
  String? _roundId;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _mode = defaultAutoFixtureMode(widget.tournament.format);
  }

  Future<void> _generate({required bool useSavedFormat}) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    setState(() => _busy = true);
    try {
      final repo = ref.read(tournamentRepositoryProvider);
      final service = ref.read(autoFixtureGeneratorServiceProvider);
      final rounds =
          ref.read(tournamentActiveRoundsProvider(widget.tournament.id));
      final round = rounds.where((r) => r.id == _roundId).firstOrNull;

      final ids = useSavedFormat
          ? await service.generate(
              repository: repo,
              tournamentId: widget.tournament.id,
              createdBy: uid,
              format: widget.tournament.format,
              roundId: _roundId,
              roundName: round?.name,
            )
          : await service.generateByMode(
              repository: repo,
              tournamentId: widget.tournament.id,
              createdBy: uid,
              mode: _mode,
              roundId: _roundId,
              roundName: round?.name,
            );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created ${ids.length} matches')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final rounds =
        ref.watch(tournamentActiveRoundsProvider(widget.tournament.id));
    final formatLabel = tournamentFormatLabel(widget.tournament.format);
    final modeOptions = orderedAutoFixtureModes(widget.tournament.format);

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
          const SizedBox(height: AppDimens.spaceSm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceSm,
              vertical: AppDimens.spaceXs,
            ),
            decoration: BoxDecoration(
              color: cf.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cf.accent.withValues(alpha: 0.25)),
            ),
            child: Text(
              'Tournament format: $formatLabel',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cf.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          CfButton(
            label: primaryFixtureActionLabel(widget.tournament.format),
            isGold: true,
            isLoading: _busy,
            onPressed: _busy ? null : () => _generate(useSavedFormat: true),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            'Or choose a different generator',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          DropdownButtonFormField<AutoFixtureMode>(
            value: _mode,
            decoration: const InputDecoration(
              labelText: 'Generator',
              border: OutlineInputBorder(),
            ),
            items: modeOptions
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
            label: 'Generate with selected mode',
            isLoading: _busy,
            onPressed: _busy ? null : () => _generate(useSavedFormat: false),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
