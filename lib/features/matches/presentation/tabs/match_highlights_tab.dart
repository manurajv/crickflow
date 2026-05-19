import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/deep_link_utils.dart';
import '../../../../core/utils/highlight_utils.dart';
import '../../../../core/utils/youtube_utils.dart';
import '../../../../data/models/ball_event_model.dart';
import '../../../../shared/providers/providers.dart';

class MatchHighlightsTab extends ConsumerWidget {
  const MatchHighlightsTab({super.key, required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(ballEventsProvider(matchId));
    final streamStartedAt =
        ref.watch(matchProvider(matchId)).valueOrNull?.stream.startedAt;

    return eventsAsync.when(
      data: (events) {
        final highlights = events.where(HighlightUtils.isHighlight).toList()
          ..sort((a, b) => b.sequence.compareTo(a.sequence));

        if (highlights.isEmpty) {
          return Center(
            child: Padding(
              padding: AppDimens.listPadding,
              child: Text(
                'No highlights yet.\nFours, sixes, and wickets appear here automatically.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          );
        }

        return ListView.builder(
          padding: AppDimens.listPadding,
          itemCount: highlights.length,
          itemBuilder: (context, index) {
            final event = highlights[index];
            return _HighlightTile(
              event: event,
              streamStartedAt: streamStartedAt,
              matchId: matchId,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }
}

class _HighlightTile extends StatelessWidget {
  const _HighlightTile({
    required this.event,
    required this.streamStartedAt,
    required this.matchId,
  });

  final BallEventModel event;
  final DateTime? streamStartedAt;
  final String matchId;

  @override
  Widget build(BuildContext context) {
    final tag = event.highlightTag ?? '';
    final offset = YoutubeUtils.offsetFromStreamStart(
      streamStartedAt: streamStartedAt,
      eventTime: event.timestamp,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _tagColor(tag),
          child: Icon(_tagIcon(tag), color: Colors.white, size: 18),
        ),
        title: Text(HighlightUtils.label(event)),
        subtitle: Text(
          '${HighlightUtils.overBallLabel(event)} • ${event.commentary}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.share_outlined),
          onPressed: () {
            final text = StringBuffer()
              ..writeln(HighlightUtils.label(event))
              ..writeln(event.commentary)
              ..writeln(DeepLinkUtils.publicLiveScorecardUri(matchId));
            if (offset != null) {
              text.writeln('Stream @ ${YoutubeUtils.formatStreamOffset(offset)}');
            }
            Share.share(text.toString());
          },
        ),
      ),
    );
  }

  Color _tagColor(String tag) {
    switch (tag) {
      case 'six':
        return AppColors.gold;
      case 'wicket':
        return AppColors.accentRed;
      default:
        return AppColors.primaryBlue;
    }
  }

  IconData _tagIcon(String tag) {
    switch (tag) {
      case 'six':
        return Icons.looks_6;
      case 'wicket':
        return Icons.sports_cricket;
      default:
        return Icons.looks_4;
    }
  }
}
