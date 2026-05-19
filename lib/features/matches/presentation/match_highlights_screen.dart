import 'package:flutter/material.dart';
import 'package:crickflow/core/theme/app_dimens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/deep_link_utils.dart';
import '../../../core/utils/highlight_utils.dart';
import '../../../core/utils/youtube_utils.dart';
import '../../../data/models/ball_event_model.dart';
import '../../../shared/providers/providers.dart';

class MatchHighlightsScreen extends ConsumerWidget {
  const MatchHighlightsScreen({super.key, required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(ballEventsProvider(matchId));
    final streamStartedAt =
        ref.watch(matchProvider(matchId)).valueOrNull?.stream.startedAt;

    return Scaffold(
      appBar: AppBar(title: const Text('Match Highlights')),
      body: eventsAsync.when(
        data: (events) {
          final highlights = events
              .where(HighlightUtils.isHighlight)
              .toList()
            ..sort((a, b) => b.sequence.compareTo(a.sequence));

          if (highlights.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppDimens.spaceLg),
                child: Text(
                  'No highlights yet.\n'
                  'Fours, sixes, and wickets appear here automatically.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            itemCount: highlights.length,
            itemBuilder: (context, index) {
              final event = highlights[index];
              return _HighlightTile(
                event: event,
                streamStartedAt: streamStartedAt,
                onShare: () => _shareHighlight(
                  matchId,
                  event,
                  streamStartedAt: streamStartedAt,
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }

  void _shareHighlight(
    String matchId,
    BallEventModel event, {
    DateTime? streamStartedAt,
  }) {
    final link = DeepLinkUtils.httpsScorecardUri(matchId).toString();
    final offset = YoutubeUtils.offsetFromStreamStart(
      streamStartedAt: streamStartedAt,
      eventTime: event.timestamp,
    );
    final offsetLine = offset != null
        ? 'Stream ~${YoutubeUtils.formatStreamOffset(offset)}\n'
        : '';
    final text =
        '${HighlightUtils.label(event)} — ${HighlightUtils.overBallLabel(event)}\n'
        '$offsetLine'
        '${event.commentary}\n$link';
    Share.share(text, subject: 'CrickFlow highlight');
  }
}

class _HighlightTile extends StatelessWidget {
  const _HighlightTile({
    required this.event,
    required this.streamStartedAt,
    required this.onShare,
  });

  final BallEventModel event;
  final DateTime? streamStartedAt;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final tag = event.highlightTag ?? HighlightUtils.classify(event).tag;
    final color = switch (tag) {
      HighlightUtils.tagSix => AppColors.gold,
      HighlightUtils.tagFour => AppColors.primaryBlueLight,
      HighlightUtils.tagWicket => Colors.redAccent,
      _ => AppColors.textMuted,
    };
    final offset = YoutubeUtils.offsetFromStreamStart(
      streamStartedAt: streamStartedAt,
      eventTime: event.timestamp,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.25),
          child: Text(
            HighlightUtils.label(event)[0],
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          '${HighlightUtils.label(event)} · Inn ${event.inningsNumber} · '
          '${HighlightUtils.overBallLabel(event)}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (offset != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Stream ${YoutubeUtils.formatStreamOffset(offset)}',
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Text(event.commentary),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.share_outlined),
          onPressed: onShare,
        ),
      ),
    );
  }
}
