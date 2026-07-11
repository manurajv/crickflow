import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../core/utils/deep_link_utils.dart';
import '../../../../core/utils/youtube_utils.dart';
import '../../../../data/models/ball_event_model.dart';
import '../../../../domain/services/commentary_feed_models.dart';
import '../../../../domain/services/commentary_feed_service.dart';
import '../../../../domain/streaming/match_stream_playback.dart';
import '../../../../domain/streaming/replay_marker_commentary.dart';
import '../../../../shared/providers/providers.dart';
import '../../../scoring/presentation/widgets/delivery_bubble.dart';
import '../../../streaming/domain/match_highlights_merger.dart';
import '../../../streaming/presentation/providers/match_highlights_merged_provider.dart';
import '../../../streaming/presentation/providers/match_stream_seek_provider.dart';

/// Highlights list — scoring moments plus stream replay flags (auto + manual).
class MatchHighlightsList extends ConsumerWidget {
  const MatchHighlightsList({
    super.key,
    required this.matchId,
    this.padding = const EdgeInsets.all(AppDimens.spaceMd),
    this.seekInAppPlayer = false,
  });

  final String matchId;
  final EdgeInsets padding;
  /// When true (match hub), highlight taps seek the in-app stream player.
  final bool seekInAppPlayer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highlights = ref.watch(matchHighlightsMergedProvider(matchId));
    final match = ref.watch(matchProvider(matchId)).valueOrNull;
    final commentaryFeed = ref.watch(commentaryFeedProvider(matchId));
    final ballById = {
      for (final event
          in ref.watch(ballEventsProvider(matchId)).valueOrNull ?? const <BallEventModel>[])
        event.id: event,
    };
    final hasStream =
        match != null && MatchStreamPlayback.hasWatchablePlayback(match);
    final canSeekInPlayer = seekInAppPlayer && hasStream;
    final youtubeUrl = match?.stream.youtubeWatchUrl;

    if (highlights.isEmpty) {
      return Center(
        child: Padding(
          padding: padding,
          child: Text(
            'No highlights yet.\n'
            'Fours, sixes, wickets, and stream replay flags appear here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.cf.textSecondary,
                ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: padding,
      itemCount: highlights.length,
      itemBuilder: (context, index) {
        final item = highlights[index];
        return _MatchHighlightTile(
          matchId: matchId,
          item: item,
          commentaryFeed: commentaryFeed,
          linkedBall: _linkedBallFor(item, ballById),
          youtubeWatchUrl: youtubeUrl,
          canSeekInPlayer: canSeekInPlayer,
          onSeek: (offsetMs) {
            if (!seekInAppPlayer) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Open the match scorecard to play highlights in the stream.',
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              return;
            }
            requestMatchStreamSeek(
              ref,
              matchId: matchId,
              offsetMs: offsetMs,
              sessionId: item.streamSessionId,
              label: item.label,
              eventTime: item.ballEvent?.timestamp ??
                  item.replayMarker?.createdAt,
            );
          },
        );
      },
    );
  }

  static BallEventModel? _linkedBallFor(
    MatchHighlightItem item,
    Map<String, BallEventModel> ballById,
  ) {
    if (item.ballEvent != null) return item.ballEvent;
    final id = item.ballEventId;
    if (id == null || id.isEmpty) return null;
    return ballById[id];
  }
}

class _MatchHighlightTile extends StatelessWidget {
  const _MatchHighlightTile({
    required this.matchId,
    required this.item,
    required this.commentaryFeed,
    required this.linkedBall,
    required this.youtubeWatchUrl,
    required this.canSeekInPlayer,
    required this.onSeek,
  });

  final String matchId;
  final MatchHighlightItem item;
  final CommentaryFeed commentaryFeed;
  final BallEventModel? linkedBall;
  final String? youtubeWatchUrl;
  final bool canSeekInPlayer;
  final ValueChanged<int> onSeek;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final canSeek = canSeekInPlayer && item.streamOffsetMs != null;
    final eventId = item.ballEventId ?? item.ballEvent?.id;
    final commentary = commentaryFeed.ballItemForEventId(eventId);

    if (commentary != null) {
      return _CommentaryHighlightCard(
        cf: cf,
        commentary: commentary,
        canSeek: canSeek,
        onSeek: canSeek ? () => onSeek(item.streamOffsetMs!) : null,
        onShare: () => _share(commentary.headline),
      );
    }

    return _ReplayHighlightCard(
      cf: cf,
      item: item,
      linkedBall: linkedBall,
      canSeek: canSeek,
      onSeek: canSeek ? () => onSeek(item.streamOffsetMs!) : null,
      onShare: () => _share(item.label),
    );
  }

  void _share(String headline) {
    final offset =
        YoutubeUtils.offsetFromMilliseconds(item.streamOffsetMs);
    final youtubeAt = YoutubeUtils.watchUrlAtOffset(youtubeWatchUrl, offset);
    final buffer = StringBuffer()
      ..writeln(headline)
      ..writeln(DeepLinkUtils.publicLiveScorecardUri(matchId));
    if (youtubeAt != null) {
      buffer.writeln(youtubeAt);
    }
    Share.share(buffer.toString(), subject: 'CrickFlow highlight');
  }
}

class _CommentaryHighlightCard extends StatelessWidget {
  const _CommentaryHighlightCard({
    required this.cf,
    required this.commentary,
    required this.canSeek,
    required this.onSeek,
    required this.onShare,
  });

  final CfColors cf;
  final BallCommentaryItem commentary;
  final bool canSeek;
  final VoidCallback? onSeek;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final headline =
        CommentaryFeedService.sanitizeDisplayText(commentary.headline);
    final description =
        CommentaryFeedService.sanitizeDisplayText(commentary.description);
    final fielderLine =
        CommentaryFeedService.sanitizeDisplayText(commentary.fielderLine ?? '');
    final wicketDetail = CommentaryFeedService.sanitizeDisplayText(
      commentary.wicketDetailLine ?? '',
    );
    final accent = _accentFor(commentary, cf);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      child: Material(
        color: cf.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          side: BorderSide(color: cf.border),
        ),
        child: InkWell(
          onTap: onSeek,
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 42,
                  child: Column(
                    children: [
                      Text(
                        commentary.ballLabel,
                        style: TextStyle(
                          color: cf.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DeliveryBubble(
                        event: commentary.event,
                        size: 28,
                        fontSize: 10,
                        marginRight: 0,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 52,
                  margin: const EdgeInsets.only(right: 10),
                  color: cf.border,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HighlightHeadline(text: headline, cf: cf),
                      if (fielderLine.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          fielderLine,
                          style: TextStyle(
                            color: cf.textSecondary,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                      if (wicketDetail.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          wicketDetail,
                          style: TextStyle(
                            color: cf.textMuted,
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      ],
                      if (commentary.isBoundary && description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: TextStyle(
                            color: cf.textSecondary,
                            fontSize: 12,
                            height: 1.35,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${commentary.teamRuns}/${commentary.teamWickets}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (canSeek)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            icon: Icon(
                              Icons.play_circle_outline,
                              color: cf.accent,
                              size: 22,
                            ),
                            tooltip: 'Play in stream',
                            onPressed: onSeek,
                          ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          icon: Icon(
                            Icons.share_outlined,
                            color: cf.textMuted,
                            size: 20,
                          ),
                          tooltip: 'Share',
                          onPressed: onShare,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _accentFor(BallCommentaryItem item, CfColors cf) {
    if (item.isWicket) return cf.statusLive;
    if (item.event.runs >= 6) return CfColors.gold;
    if (item.event.runs == 4) return cf.accent;
    return cf.textPrimary;
  }
}

class _ReplayHighlightCard extends StatelessWidget {
  const _ReplayHighlightCard({
    required this.cf,
    required this.item,
    required this.linkedBall,
    required this.canSeek,
    required this.onSeek,
    required this.onShare,
  });

  final CfColors cf;
  final MatchHighlightItem item;
  final BallEventModel? linkedBall;
  final bool canSeek;
  final VoidCallback? onSeek;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final marker = item.replayMarker;
    final presentation = marker != null
        ? ReplayMarkerCommentary.present(marker, ball: linkedBall)
        : null;
    final title = presentation?.title ?? item.label;
    final subtitle = presentation?.subtitle;
    final scoreRuns = linkedBall?.teamScoreAtWicket;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      child: Material(
        color: cf.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          side: BorderSide(color: cf.border),
        ),
        child: InkWell(
          onTap: onSeek,
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (linkedBall != null)
                  SizedBox(
                    width: 42,
                    child: Column(
                      children: [
                        Text(
                          '${linkedBall!.overNumber}.${linkedBall!.ballInOver}',
                          style: TextStyle(
                            color: cf.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DeliveryBubble(
                          event: linkedBall!,
                          size: 28,
                          fontSize: 10,
                          marginRight: 0,
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cf.surfaceElevated,
                      border: Border.all(color: cf.border),
                    ),
                    child: Icon(
                      Icons.flag_outlined,
                      size: 18,
                      color: cf.textMuted,
                    ),
                  ),
                if (linkedBall != null) ...[
                  Container(
                    width: 1,
                    height: 52,
                    margin: const EdgeInsets.only(right: 10),
                    color: cf.border,
                  ),
                ] else
                  const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: cf.textPrimary,
                          height: 1.3,
                        ),
                      ),
                      if (subtitle != null && subtitle.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: cf.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (scoreRuns != null)
                      Text(
                        '$scoreRuns',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: cf.textPrimary,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (canSeek)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            icon: Icon(
                              Icons.play_circle_outline,
                              color: cf.accent,
                              size: 22,
                            ),
                            tooltip: 'Play in stream',
                            onPressed: onSeek,
                          ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          icon: Icon(
                            Icons.share_outlined,
                            color: cf.textMuted,
                            size: 20,
                          ),
                          tooltip: 'Share',
                          onPressed: onShare,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HighlightHeadline extends StatelessWidget {
  const _HighlightHeadline({required this.text, required this.cf});

  final String text;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    final parts = text.split('\n');
    if (parts.length < 2) {
      return Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: cf.textPrimary,
          height: 1.35,
        ),
      );
    }
    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 13, color: cf.textPrimary, height: 1.3),
        children: [
          TextSpan(
            text: parts[0],
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const TextSpan(text: '\n'),
          TextSpan(
            text: parts.sublist(1).join('\n'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
