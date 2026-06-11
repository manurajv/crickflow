import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/match_model.dart';
import '../../../../shared/providers/lineup_providers.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/scoring_ui_kit.dart';
import 'cf_selection_card.dart';

/// Bottom sheet to flip toss winner's bat/bowl choice (swaps batting & bowling).
class EditTossDecisionSheet extends ConsumerStatefulWidget {
  const EditTossDecisionSheet({
    super.key,
    required this.matchId,
    required this.match,
    this.redirectToLineup = false,
  });

  final String matchId;
  final MatchModel match;
  /// After save, go to start-innings so scorer re-picks lineup for swapped teams.
  final bool redirectToLineup;

  static Future<void> show(
    BuildContext context, {
    required String matchId,
    required MatchModel match,
    bool redirectToLineup = false,
  }) {
    return ScoringUiKit.showSheet<void>(
      context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(ctx).bottom + AppDimens.spaceMd,
        ),
        child: EditTossDecisionSheet(
          matchId: matchId,
          match: match,
          redirectToLineup: redirectToLineup,
        ),
      ),
    );
  }

  @override
  ConsumerState<EditTossDecisionSheet> createState() =>
      _EditTossDecisionSheetState();
}

class _EditTossDecisionSheetState extends ConsumerState<EditTossDecisionSheet> {
  late bool _winnerBatsFirst;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _winnerBatsFirst = widget.match.setup!.tossWinnerBatsFirst!;
  }

  String get _winnerName {
    final setup = widget.match.setup!;
    return setup.tossWinnerIsTeamA!
        ? widget.match.teamAName
        : widget.match.teamBName;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(matchRepositoryProvider).updateTossElection(
            widget.matchId,
            winnerBatsFirst: _winnerBatsFirst,
          );
      ref.invalidate(matchLineupSquadsProvider(widget.matchId));
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Toss decision updated')),
        );
        if (widget.redirectToLineup) {
          context.go('/match/${widget.matchId}/start-innings');
        }
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

  @override
  Widget build(BuildContext context) {
    final elected = _winnerBatsFirst ? 'bat' : 'bowl';
    final otherTeam = _winnerBatsFirst
        ? (widget.match.setup!.tossWinnerIsTeamA!
            ? widget.match.teamBName
            : widget.match.teamAName)
        : (widget.match.setup!.tossWinnerIsTeamA!
            ? widget.match.teamAName
            : widget.match.teamBName);

    return Material(
      color: AppColors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScoringSheetHeader(
            title: 'Change toss decision',
            trailing: ScoringUiKit.sheetCloseButton(context),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
          Text(
            '$_winnerName won the toss. Changing bat/bowl will swap which team '
            'is batting and bowling for this innings.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppDimens.spaceLg),
          Text(
            '$_winnerName elected to',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              CfSelectionCard(
                label: 'Bat',
                icon: Icons.sports_cricket,
                selected: _winnerBatsFirst,
                onTap: () => setState(() => _winnerBatsFirst = true),
              ),
              CfSelectionCard(
                label: 'Bowl',
                icon: Icons.sports_baseball,
                selected: !_winnerBatsFirst,
                onTap: () => setState(() => _winnerBatsFirst = false),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            '$_winnerName will $elected · $otherTeam will ${_winnerBatsFirst ? 'bowl' : 'bat'}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppDimens.spaceLg),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
