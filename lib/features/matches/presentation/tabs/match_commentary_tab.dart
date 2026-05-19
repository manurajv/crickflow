import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/ball_event_model.dart';
import '../../../../shared/providers/providers.dart';

/// Ball-by-ball commentary timeline (Comms tab).
class MatchCommentaryTab extends ConsumerWidget {
  const MatchCommentaryTab({super.key, required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(ballEventsProvider(matchId));

    return eventsAsync.when(
      data: (events) {
        if (events.isEmpty) {
          return Center(
            child: Text(
              'No balls yet.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }
        final reversed = events.reversed.toList();
        return ListView.separated(
          padding: AppDimens.listPadding,
          itemCount: reversed.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final e = reversed[i];
            return _CommentaryTile(event: e);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }
}

class _CommentaryTile extends StatelessWidget {
  const _CommentaryTile({required this.event});

  final BallEventModel event;

  @override
  Widget build(BuildContext context) {
    final ballLabel = '${event.overNumber}.${event.ballInOver}';
    final color = _ballColor(event);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 36,
          child: Column(
            children: [
              Text(
                ballLabel,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 2),
              CircleAvatar(
                radius: 12,
                backgroundColor: color,
                child: Text(
                  _ballShort(event),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppDimens.spaceMd),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
            child: Text(
              event.commentary.isNotEmpty
                  ? event.commentary
                  : '${event.eventType.name} — ${event.runs} run(s)',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
      ],
    );
  }

  Color _ballColor(BallEventModel e) {
    if (e.eventType == BallEventType.wicket) return AppColors.accentRed;
    if (e.runs >= 6) return AppColors.gold;
    if (e.runs == 4) return AppColors.primaryBlue;
    return AppColors.surfaceElevated;
  }

  String _ballShort(BallEventModel e) {
    if (e.eventType == BallEventType.wicket) return 'W';
    if (e.eventType == BallEventType.wide) return 'Wd';
    if (e.eventType == BallEventType.noBall) return 'Nb';
    if (e.runs == 0) return '·';
    return '${e.runs}';
  }
}
