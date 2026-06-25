import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_dimens.dart';
import '../../../../../data/models/match_model.dart';
import '../../../../../shared/providers/providers.dart';
import '../../../../../shared/widgets/cf_button.dart';

Future<void> showWalkoverMatchSheet(
  BuildContext context,
  WidgetRef ref, {
  required MatchModel match,
  required String tournamentId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _WalkoverMatchSheet(
      match: match,
      tournamentId: tournamentId,
      ref: ref,
    ),
  );
}

class _WalkoverMatchSheet extends ConsumerStatefulWidget {
  const _WalkoverMatchSheet({
    required this.match,
    required this.tournamentId,
    required this.ref,
  });

  final MatchModel match;
  final String tournamentId;
  final WidgetRef ref;

  @override
  ConsumerState<_WalkoverMatchSheet> createState() =>
      _WalkoverMatchSheetState();
}

class _WalkoverMatchSheetState extends ConsumerState<_WalkoverMatchSheet> {
  String? _winnerTeamId;
  var _reason = 'Walkover';
  var _saving = false;

  static const _reasons = ['Walkover', 'Forfeit', 'No show'];

  @override
  Widget build(BuildContext context) {
    final match = widget.match;

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
            'Declare walkover',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            '${match.teamAName} vs ${match.teamBName}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            'Winning team',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: AppDimens.spaceSm),
          if (match.teamAId != null)
            RadioListTile<String>(
              value: match.teamAId!,
              groupValue: _winnerTeamId,
              title: Text(match.teamAName),
              onChanged: (v) => setState(() => _winnerTeamId = v),
            ),
          if (match.teamBId != null)
            RadioListTile<String>(
              value: match.teamBId!,
              groupValue: _winnerTeamId,
              title: Text(match.teamBName),
              onChanged: (v) => setState(() => _winnerTeamId = v),
            ),
          const SizedBox(height: AppDimens.spaceSm),
          DropdownButtonFormField<String>(
            value: _reason,
            decoration: const InputDecoration(labelText: 'Reason'),
            items: _reasons
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _reason = v);
            },
          ),
          const SizedBox(height: AppDimens.spaceMd),
          CfButton(
            label: 'Confirm walkover',
            isGold: true,
            isLoading: _saving,
            onPressed: _winnerTeamId == null || _saving ? null : _submit,
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      await widget.ref.read(tournamentRepositoryProvider).declareWalkover(
            matchId: widget.match.id,
            winnerTeamId: _winnerTeamId!,
            reason: _reason,
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Walkover recorded')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
