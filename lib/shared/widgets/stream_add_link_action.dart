import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/enums.dart';
import '../../data/models/match_model.dart';
import '../../domain/streaming/match_stream_playback.dart';
import '../../features/streaming/presentation/providers/streaming_studio_providers.dart';
import '../../shared/providers/providers.dart';
import 'match_stream_watch_section.dart';

/// Whether an authorized user can paste/update a public watch link for this match.
bool shouldOfferStreamAddLink(MatchModel match) {
  return match.status == MatchStatus.live ||
      match.status == MatchStatus.inningsBreak ||
      match.status == MatchStatus.completed ||
      match.stream.status == StreamStatus.live ||
      match.stream.status == StreamStatus.connecting;
}

/// App-bar control to paste a public watch URL. Shows a dot when none is saved.
class StreamAddLinkAction extends ConsumerWidget {
  const StreamAddLinkAction({
    super.key,
    required this.matchId,
    this.match,
  });

  final String matchId;
  final MatchModel? match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolved = match ?? ref.watch(matchProvider(matchId)).valueOrNull;
    if (resolved == null) return const SizedBox.shrink();

    final canStart = ref.watch(streamCanStartProvider(matchId));
    if (!canStart || !shouldOfferStreamAddLink(resolved)) {
      return const SizedBox.shrink();
    }

    final showDot = !MatchStreamPlayback.hasWatchablePlayback(resolved);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: TextButton(
        onPressed: () => showStreamWatchUrlSheet(
          context: context,
          matchId: matchId,
          match: resolved,
          title: 'Add stream link',
        ),
        style: TextButton.styleFrom(
          foregroundColor: theme.colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            const Text(
              'Add stream link',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            if (showDot)
              Positioned(
                right: -6,
                top: -2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.surface,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
