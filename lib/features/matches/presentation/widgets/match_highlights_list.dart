import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/deep_link_utils.dart';
import '../../../../core/utils/youtube_utils.dart';
import '../../../../shared/providers/providers.dart';
import '../../../streaming/domain/match_highlights_merger.dart';
import '../../../streaming/presentation/providers/match_highlights_merged_provider.dart';

/// Shared highlights list — ball events + stream replay markers.
class MatchHighlightsList extends ConsumerWidget {
  const MatchHighlightsList({
    super.key,
    required this.matchId,
    this.padding = const EdgeInsets.all(AppDimens.spaceMd),
  });

  final String matchId;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highlights = ref.watch(matchHighlightsMergedProvider(matchId));
    final match = ref.watch(matchProvider(matchId)).valueOrNull;
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
                  color: AppColors.textSecondary,
                ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: padding,
      itemCount: highlights.length,
      itemBuilder: (context, index) {
        return _MatchHighlightTile(
          matchId: matchId,
          item: highlights[index],
          youtubeWatchUrl: youtubeUrl,
        );
      },
    );
  }
}

class _MatchHighlightTile extends StatelessWidget {
  const _MatchHighlightTile({
    required this.matchId,
    required this.item,
    required this.youtubeWatchUrl,
  });

  final String matchId;
  final MatchHighlightItem item;
  final String? youtubeWatchUrl;

  @override
  Widget build(BuildContext context) {
    final tag = item.highlightTag ?? '';
    final offset = YoutubeUtils.offsetFromMilliseconds(item.streamOffsetMs);
    final youtubeAt = YoutubeUtils.watchUrlAtOffset(youtubeWatchUrl, offset);

    return Card(
      margin: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _tagColor(tag).withValues(alpha: 0.25),
          child: Icon(_tagIcon(tag), color: _tagColor(tag), size: 18),
        ),
        title: Text(
          item.label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (offset != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Stream ${YoutubeUtils.formatStreamOffset(offset)}'
                  '${item.source == MatchHighlightSource.replayMarker ? ' · replay flag' : ''}',
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Text(
              item.subtitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (youtubeAt != null)
              IconButton(
                icon: const Icon(Icons.play_circle_outline),
                tooltip: 'Open in YouTube',
                onPressed: () => launchUrl(
                  Uri.parse(youtubeAt),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            IconButton(
              icon: const Icon(Icons.share_outlined),
              onPressed: () => _share(youtubeAt, offset),
            ),
          ],
        ),
      ),
    );
  }

  void _share(String? youtubeAt, Duration? offset) {
    final buffer = StringBuffer()
      ..writeln(item.label)
      ..writeln(item.subtitle)
      ..writeln(DeepLinkUtils.publicLiveScorecardUri(matchId));
    if (offset != null) {
      buffer.writeln('Stream @ ${YoutubeUtils.formatStreamOffset(offset)}');
    }
    if (youtubeAt != null) {
      buffer.writeln(youtubeAt);
    }
    Share.share(buffer.toString(), subject: 'CrickFlow highlight');
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
