import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/ball_event_model.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/scoring_ui_kit.dart';

/// Recent ball events for scorer corrections (undo via existing flow).
class ScoringMistakeSheet extends ConsumerStatefulWidget {
  const ScoringMistakeSheet({super.key, required this.matchId});

  final String matchId;

  static Future<void> show(BuildContext context, {required String matchId}) {
    return ScoringUiKit.showSheet<void>(
      context,
      isScrollControlled: true,
      builder: (_) => ScoringMistakeSheet(matchId: matchId),
    );
  }

  @override
  ConsumerState<ScoringMistakeSheet> createState() =>
      _ScoringMistakeSheetState();
}

class _ScoringMistakeSheetState extends ConsumerState<ScoringMistakeSheet> {
  var _undoing = false;
  var _showEditHistory = false;

  Future<void> _undoLast() async {
    setState(() => _undoing = true);
    try {
      await ref.read(matchRepositoryProvider).undoLastBall(widget.matchId);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Last ball undone')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Undo failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _undoing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(ballEventsProvider(widget.matchId));

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScoringSheetHeader(title: 'Scoring Mistake'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CfButton(
                    label: _undoing ? 'Undoing…' : 'Open Undo History',
                    onPressed: _undoing ? null : _undoLast,
                  ),
                  const SizedBox(height: AppDimens.spaceSm),
                  OutlinedButton(
                    onPressed: () =>
                        setState(() => _showEditHistory = !_showEditHistory),
                    child: Text(
                      _showEditHistory
                          ? 'Hide Ball Edit History'
                          : 'Open Ball Edit History',
                    ),
                  ),
                  const SizedBox(height: AppDimens.spaceSm),
                  Text(
                    'Last 20 scoring events.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Expanded(
              child: eventsAsync.when(
                data: (events) {
                  final recent = events.reversed.take(20).toList();
                  if (recent.isEmpty) {
                    return const Center(child: Text('No balls recorded yet'));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(AppDimens.spaceMd),
                    itemCount: recent.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final e = recent[i];
                      return _EventRow(
                        event: e,
                        highlightEdit: _showEditHistory,
                      );
                    },
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    this.highlightEdit = false,
  });

  final BallEventModel event;
  final bool highlightEdit;

  @override
  Widget build(BuildContext context) {
    final over =
        '${event.overNumber}.${event.ballInOver} (Inn ${event.inningsNumber})';
    final type = event.eventType.name;
    final runs = event.runs;
    final extras = event.runs - event.batsmanRuns;
    final batter = event.lineupStrikerName ?? event.strikerId ?? '—';
    final bowler = event.bowlerName ?? event.bowlerId ?? '—';
    final wicket = event.eventType == BallEventType.wicket
        ? (event.dismissalText ?? event.wicketType?.name ?? 'Wicket')
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            over,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text('$type · $runs runs · Extras $extras'),
          Text('Batter: $batter · Bowler: $bowler'),
          if (wicket != null)
            Text('Wicket: $wicket',
                style: const TextStyle(color: AppColors.gold)),
          if (highlightEdit)
            const Text(
              'Ball event record',
              style: TextStyle(color: AppColors.gold, fontSize: 12),
            ),
          if (event.commentary.isNotEmpty)
            Text(
              event.commentary,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }
}
