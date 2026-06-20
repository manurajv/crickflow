import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/player_model.dart';
import '../../../../domain/services/commentary_feed_models.dart';
import '../../../../domain/services/commentary_feed_service.dart';
import '../../../../shared/providers/match_squads_provider.dart';
import '../../../../shared/providers/providers.dart';
import '../widgets/commentary/commentary_feed_widgets.dart';

/// Professional ball-by-ball commentary center (Comms tab).
class MatchCommentaryTab extends ConsumerStatefulWidget {
  const MatchCommentaryTab({super.key, required this.matchId});

  final String matchId;

  @override
  ConsumerState<MatchCommentaryTab> createState() => _MatchCommentaryTabState();
}

class _MatchCommentaryTabState extends ConsumerState<MatchCommentaryTab> {
  int? _selectedInnings;
  CommentaryFilter _filter = CommentaryFilter.full;

  static const _activeFilters = CommentaryFilter.values;

  @override
  Widget build(BuildContext context) {
    final matchAsync = ref.watch(matchProvider(widget.matchId));
    final feed = ref.watch(commentaryFeedProvider(widget.matchId));
    final squadsAsync = ref.watch(matchDualSquadsProvider(widget.matchId));

    return matchAsync.when(
      data: (match) {
        if (match == null) {
          return const Center(child: Text('Match not found'));
        }

        if (feed.inningsOptions.isEmpty) {
          return Center(
            child: Text(
              'No innings yet.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }

        final inningsNumber = _selectedInnings ??
            match.currentInnings?.inningsNumber ??
            feed.inningsOptions.last.inningsNumber;

        final innings = match.innings.firstWhere(
          (i) => i.inningsNumber == inningsNumber,
          orElse: () => match.innings.first,
        );
        final teamOption = feed.inningsOptions.firstWhere(
          (o) => o.inningsNumber == inningsNumber,
          orElse: () => feed.inningsOptions.first,
        );
        final items = feed.filtered(
          inningsNumber: inningsNumber,
          filter: _filter,
        );

        final players = squadsAsync.valueOrNull;
        final playerMap = <String, PlayerModel>{};
        if (players != null) {
          for (final p in players.teamAPlayers) {
            playerMap[p.id] = p;
          }
          for (final p in players.teamBPlayers) {
            playerMap[p.id] = p;
          }
        }

        final contextLine =
            CommentaryFeedService.primaryContextLine(match, innings);
        final cf = context.cf;

        return ColoredBox(
          color: cf.card,
          child: Column(
            children: [
              CommentaryFilterBar(
                teamLabel: teamOption.teamName.toUpperCase(),
                filterLabel: _filter.label.toUpperCase(),
                onTeamTap: () => _pickInnings(context, feed.inningsOptions),
                onFilterTap: () => _pickFilter(context),
              ),
              if (contextLine != null)
                CommentaryContextBanner(text: contextLine),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Text(
                          _emptyMessage(_filter),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: cf.textMuted,
                              ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            const CommentaryFeedDivider(),
                        itemBuilder: (context, index) {
                          return _FeedItemTile(
                            item: items[index],
                            filter: _filter,
                            playerMap: playerMap,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(
        child: Text('Unable to load commentary'),
      ),
    );
  }

  String _emptyMessage(CommentaryFilter filter) {
    return switch (filter) {
      CommentaryFilter.full => 'No commentary yet.',
      CommentaryFilter.wickets => 'No wickets in this innings.',
      CommentaryFilter.boundaries => 'No boundaries yet.',
      CommentaryFilter.overs => 'No completed overs yet.',
      CommentaryFilter.powerplays => 'No powerplay events.',
    };
  }

  Future<void> _pickInnings(
    BuildContext context,
    List<CommentaryInningsOption> options,
  ) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppDimens.spaceMd),
              child: Text(
                'Select innings',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            ...options.map(
              (o) => ListTile(
                title: Text(o.teamName),
                subtitle: Text('Innings ${o.inningsNumber}'),
                onTap: () => Navigator.pop(ctx, o.inningsNumber),
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _selectedInnings = picked);
  }

  Future<void> _pickFilter(BuildContext context) async {
    final picked = await showModalBottomSheet<CommentaryFilter>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _activeFilters
              .map(
                (f) => ListTile(
                  title: Text(f.label),
                  trailing: _filter == f
                      ? Icon(Icons.check, color: context.cf.accent)
                      : null,
                  onTap: () => Navigator.pop(ctx, f),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (picked != null) setState(() => _filter = picked);
  }
}

class _FeedItemTile extends StatelessWidget {
  const _FeedItemTile({
    required this.item,
    required this.filter,
    required this.playerMap,
  });

  final CommentaryFeedItem item;
  final CommentaryFilter filter;
  final Map<String, PlayerModel> playerMap;

  @override
  Widget build(BuildContext context) {
    return switch (item) {
      BallCommentaryItem i => CommentaryBallCard(item: i, filter: filter),
      OverSummaryCommentaryItem i when filter == CommentaryFilter.overs =>
        CommentaryOversRow(item: i),
      OverSummaryCommentaryItem i => CommentaryOverSummaryCard(
          item: i,
          compact: filter == CommentaryFilter.boundaries,
          highlighted: filter == CommentaryFilter.full ||
              filter == CommentaryFilter.wickets,
        ),
      NextBatterCommentaryItem i => CommentaryNextBatterCard(
          item: i,
          player: playerMap[i.playerId],
        ),
      MatchEventCommentaryItem i => CommentaryPowerplayCard(item: i),
    };
  }
}
