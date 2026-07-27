import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/enums.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../data/models/location_model.dart';
import '../../../domain/services/player_rankings/player_rankings_models.dart';
import '../../../domain/services/player_typed_stats_service.dart';
import '../../../shared/providers/player_rankings_provider.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';
import 'widgets/player_rankings_filter_sheet.dart';

class PlayerRankingsScreen extends ConsumerStatefulWidget {
  const PlayerRankingsScreen({super.key});

  @override
  ConsumerState<PlayerRankingsScreen> createState() =>
      _PlayerRankingsScreenState();
}

class _PlayerRankingsScreenState extends ConsumerState<PlayerRankingsScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  var _searchOpen = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 420) {
      ref.read(playerRankingsFeedControllerProvider.notifier).loadMore();
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      updatePlayerRankingsFilter(
        ref,
        (f) => f.copyWith(searchQuery: value),
      );
    });
  }

  Future<void> _openFilterSheet() async {
    final current = ref.read(playerRankingsFilterProvider);
    final result = await showPlayerRankingsFilterSheet(
      context,
      initial: current,
      onUseCurrentLocation: _resolveCurrentLocation,
      locationService: ref.read(googleMapsLocationServiceProvider),
    );
    if (result == null || !mounted) return;
    ref.read(playerRankingsFilterProvider.notifier).state = result;
  }

  Future<LocationModel?> _resolveCurrentLocation() async {
    final service = ref.read(googleMapsLocationServiceProvider);
    final coords = await service.getCurrentCoords();
    if (coords == null) return null;
    final place = await service.reverseGeocode(coords);
    return place.location;
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final filter = ref.watch(playerRankingsFilterProvider);
    final feed = ref.watch(playerRankingsFeedControllerProvider);
    final maxListWidth = MediaQuery.sizeOf(context).width > 720 ? 720.0 : null;

    return Scaffold(
      backgroundColor: cf.background,
      appBar: CfChromeAppBar(
        title: _searchOpen
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search player, username, team',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: cf.textMuted),
                ),
                style: TextStyle(color: cf.textPrimary),
                onChanged: _onSearchChanged,
              )
            : const Text('Player Rankings'),
        actions: [
          IconButton(
            tooltip: _searchOpen ? 'Close search' : 'Search',
            icon: Icon(_searchOpen ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _searchOpen = !_searchOpen;
                if (!_searchOpen) {
                  _searchController.clear();
                  updatePlayerRankingsFilter(
                    ref,
                    (f) => f.copyWith(searchQuery: ''),
                  );
                }
              });
            },
          ),
          IconButton(
            tooltip: 'Filter',
            icon: Badge(
              isLabelVisible: filter.hasAdvancedFilters,
              smallSize: 8,
              child: const Icon(Icons.tune),
            ),
            onPressed: _openFilterSheet,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxListWidth ?? double.infinity,
          ),
          child: Column(
            children: [
              _ChipRow(
                children: [
                  for (final type in CricketBallType.values)
                    Padding(
                      padding: const EdgeInsets.only(right: AppDimens.spaceXs),
                      child: FilterChip(
                        label: Text(cricketBallTypeLabel(type)),
                        selected: filter.ballType == type,
                        onSelected: (_) => updatePlayerRankingsFilter(
                          ref,
                          (f) => f.copyWith(
                            ballType: type,
                            clearIndoorBallMaterial:
                                type != CricketBallType.indoor,
                          ),
                        ),
                        selectedColor: cf.accent.withValues(alpha: 0.15),
                        checkmarkColor: cf.accent,
                      ),
                    ),
                ],
              ),
              if (filter.ballType == CricketBallType.indoor)
                _ChipRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: AppDimens.spaceXs),
                      child: FilterChip(
                        label: const Text('All indoor'),
                        selected: filter.indoorBallMaterial == null,
                        onSelected: (_) => updatePlayerRankingsFilter(
                          ref,
                          (f) => f.copyWith(clearIndoorBallMaterial: true),
                        ),
                        selectedColor: cf.accent.withValues(alpha: 0.15),
                        checkmarkColor: cf.accent,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: AppDimens.spaceXs),
                      child: FilterChip(
                        label: const Text('Leather'),
                        selected: filter.indoorBallMaterial ==
                            CricketBallType.leather,
                        onSelected: (_) => updatePlayerRankingsFilter(
                          ref,
                          (f) => f.copyWith(
                            indoorBallMaterial: CricketBallType.leather,
                          ),
                        ),
                        selectedColor: cf.accent.withValues(alpha: 0.15),
                        checkmarkColor: cf.accent,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: AppDimens.spaceXs),
                      child: FilterChip(
                        label: const Text('Tennis'),
                        selected:
                            filter.indoorBallMaterial == CricketBallType.tennis,
                        onSelected: (_) => updatePlayerRankingsFilter(
                          ref,
                          (f) => f.copyWith(
                            indoorBallMaterial: CricketBallType.tennis,
                          ),
                        ),
                        selectedColor: cf.accent.withValues(alpha: 0.15),
                        checkmarkColor: cf.accent,
                      ),
                    ),
                  ],
                ),
              _ChipRow(
                children: [
                  for (final section in PlayerRankingsSection.values)
                    Padding(
                      padding: const EdgeInsets.only(right: AppDimens.spaceXs),
                      child: FilterChip(
                        label: Text(section.title),
                        selected: filter.section == section,
                        onSelected: (_) => updatePlayerRankingsFilter(
                          ref,
                          (f) => f.copyWith(section: section),
                        ),
                        selectedColor: cf.accent.withValues(alpha: 0.15),
                        checkmarkColor: cf.accent,
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.spaceMd,
                  AppDimens.spaceXs,
                  AppDimens.spaceMd,
                  AppDimens.spaceXs,
                ),
                child: DropdownButtonFormField<PlayerRankingsCategory>(
                  key: ValueKey('${filter.section}_${filter.category}'),
                  initialValue: filter.category,
                  decoration: InputDecoration(
                    labelText: 'Performance',
                    filled: true,
                    fillColor: cf.surfaceElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: cf.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: cf.border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spaceMd,
                      vertical: AppDimens.spaceSm,
                    ),
                  ),
                  items: [
                    for (final c in filter.section.categories)
                      DropdownMenuItem(value: c, child: Text(c.title)),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    updatePlayerRankingsFilter(
                      ref,
                      (f) => f.copyWith(category: value),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.spaceMd,
                  0,
                  AppDimens.spaceMd,
                  AppDimens.spaceSm,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    filter.advancedFilterSummary,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cf.textSecondary,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                  ),
                ),
              ),
              Expanded(child: _buildBody(context, cf, feed, filter)),
              if (feed.myEntry != null)
                _MyRankBar(entry: feed.myEntry!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    CfColors cf,
    PlayerRankingsFeedState feed,
    PlayerRankingsFilter filter,
  ) {
    if (feed.loading && feed.entries.isEmpty) {
      return const PlayerRankingsSkeleton();
    }

    if (feed.error != null && feed.entries.isEmpty) {
      return _EmptyState(
        icon: Icons.error_outline,
        title: 'Unable to load rankings',
        subtitle: '${feed.error}',
        actionLabel: 'Retry',
        onAction: () =>
            ref.read(playerRankingsFeedControllerProvider.notifier).refresh(),
      );
    }

    if (feed.entries.isEmpty) {
      final needsReplay = filter.category.requiresMatchReplay;
      final yearLabel = filter.year != null ? ' for ${filter.year}' : '';
      return _EmptyState(
        icon: Icons.leaderboard_outlined,
        title: needsReplay
            ? 'Detailed ranking coming soon'
            : 'No rankings yet$yearLabel',
        subtitle: needsReplay
            ? '${filter.category.title} needs ball-by-ball match data. '
                'Try another performance filter.'
            : filter.year != null
                ? 'No completed matches with scored stats found for ${filter.year}. '
                    'Try All Time, another ball type, or clear location.'
                : 'No players match these filters yet. Try another category or clear location.',
      );
    }

    final bottomPad = feed.myEntry != null ? 12.0 : 0.0;

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(playerRankingsFeedControllerProvider.notifier).refresh(),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppDimens.listPadding.copyWith(bottom: 16 + bottomPad),
        itemCount: feed.entries.length + (feed.loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= feed.entries.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final entry = feed.entries[index];
          final isMe = feed.myEntry?.playerDocId == entry.playerDocId;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
            child: _RankingCard(entry: entry, highlightAsYou: isMe),
          );
        },
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
        children: children,
      ),
    );
  }
}

class _RankingCard extends StatelessWidget {
  const _RankingCard({
    required this.entry,
    this.highlightAsYou = false,
    this.compact = false,
  });

  final PlayerRankingEntry entry;
  final bool highlightAsYou;
  final bool compact;

  Color _medalColor(CfColors cf) {
    final light = cf.isLight;
    return switch (entry.rank) {
      1 => light ? const Color(0xFFB8860B) : const Color(0xFFFFC107),
      2 => light ? const Color(0xFF546E7A) : const Color(0xFFB0BEC5),
      3 => light ? const Color(0xFF8D6E63) : const Color(0xFFFFAB91),
      _ => cf.accent,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final isTopThree = entry.rank <= 3;
    final rankColor = _medalColor(cf);
    final fillAlpha = cf.isLight ? 0.14 : 0.08;
    final borderAlpha = cf.isLight ? 0.55 : 0.45;
    final youAccent = cf.accent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        onTap: () {
          final publicId = entry.publicPlayerId?.trim();
          if (publicId != null && publicId.isNotEmpty) {
            context.push('/player/$publicId');
          } else {
            context.push('/players/${entry.playerDocId}');
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: highlightAsYou
                ? youAccent.withValues(alpha: cf.isLight ? 0.10 : 0.14)
                : isTopThree
                    ? rankColor.withValues(alpha: fillAlpha)
                    : cf.card,
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            border: Border.all(
              color: highlightAsYou
                  ? youAccent.withValues(alpha: 0.55)
                  : isTopThree
                      ? rankColor.withValues(alpha: borderAlpha)
                      : cf.border.withValues(alpha: 0.5),
              width: highlightAsYou || isTopThree ? 1.4 : 1,
            ),
            boxShadow: isTopThree || highlightAsYou
                ? [
                    BoxShadow(
                      color: (highlightAsYou ? youAccent : rankColor)
                          .withValues(alpha: cf.isLight ? 0.12 : 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          padding: EdgeInsets.all(
            compact ? AppDimens.spaceSm + 2 : AppDimens.spaceMd,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: compact ? 36 : 40,
                height: compact ? 36 : 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (highlightAsYou ? youAccent : rankColor)
                      .withValues(alpha: cf.isLight ? 0.22 : 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '#${entry.rank}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: highlightAsYou ? youAccent : rankColor,
                        fontSize: compact ? 12 : null,
                      ),
                ),
              ),
              const SizedBox(width: AppDimens.spaceMd),
              CircleAvatar(
                radius: compact ? 18 : 22,
                backgroundColor: cf.border,
                backgroundImage: entry.photoUrl != null &&
                        entry.photoUrl!.isNotEmpty
                    ? CachedNetworkImageProvider(entry.photoUrl!)
                    : null,
                child: entry.photoUrl == null || entry.photoUrl!.isEmpty
                    ? Text(
                        entry.playerName.isNotEmpty
                            ? entry.playerName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      )
                    : null,
              ),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            entry.playerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (highlightAsYou) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: youAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'You',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: youAccent,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10,
                                  ),
                            ),
                          ),
                        ] else if (entry.verified) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.verified,
                            size: 16,
                            color: cf.accent,
                          ),
                        ],
                      ],
                    ),
                    if (!compact) ...[
                      if (entry.role.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          entry.role,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: cf.textSecondary,
                                  ),
                        ),
                      ],
                      if (entry.detailStats.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _DetailStatsRow(stats: entry.detailStats),
                      ],
                    ] else if (entry.detailStats.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _DetailStatsRow(stats: entry.detailStats),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Text(
                entry.valueLabel,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: highlightAsYou
                          ? youAccent
                          : isTopThree
                              ? rankColor
                              : cf.textPrimary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyRankBar extends StatelessWidget {
  const _MyRankBar({required this.entry});

  final PlayerRankingEntry entry;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Material(
      elevation: 8,
      color: cf.surfaceElevated,
      shadowColor: cf.cardShadow,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.spaceMd,
            AppDimens.spaceSm,
            AppDimens.spaceMd,
            AppDimens.spaceSm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'YOUR RANK',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cf.textMuted,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
              ),
              const SizedBox(height: 6),
              _RankingCard(
                entry: entry,
                highlightAsYou: true,
                compact: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailStatsRow extends StatelessWidget {
  const _DetailStatsRow({required this.stats});

  final List<PlayerRankingStat> stats;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: cf.textMuted,
          fontWeight: FontWeight.w600,
          fontSize: 10,
          height: 1.1,
        );
    final valueStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: cf.textSecondary,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          height: 1.1,
        );

    return Wrap(
      spacing: 10,
      runSpacing: 4,
      children: [
        for (final s in stats)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${s.label} ', style: labelStyle),
              Text(s.value, style: valueStyle),
            ],
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppDimens.spaceXl),
      children: [
        const SizedBox(height: 48),
        Icon(icon, size: 52, color: cf.textMuted),
        const SizedBox(height: AppDimens.spaceMd),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppDimens.spaceXs),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cf.textSecondary,
              ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: AppDimens.spaceLg),
          Center(
            child: FilledButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ),
        ],
      ],
    );
  }
}

class PlayerRankingsSkeleton extends StatelessWidget {
  const PlayerRankingsSkeleton({super.key, this.count = 8});

  final int count;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: AppDimens.listPadding,
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: AppDimens.spaceSm),
      itemBuilder: (_, _) => Container(
        padding: AppDimens.cardPadding,
        decoration: BoxDecoration(
          color: cf.card,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          border: Border.all(color: cf.border.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            _box(cf, 40, 40, radius: 10),
            const SizedBox(width: AppDimens.spaceMd),
            _box(cf, 44, 44, radius: 22),
            const SizedBox(width: AppDimens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _box(cf, 140, 12),
                  const SizedBox(height: 6),
                  _box(cf, 100, 10),
                  const SizedBox(height: 6),
                  _box(cf, 80, 8),
                ],
              ),
            ),
            _box(cf, 36, 18),
          ],
        ),
      ),
    );
  }

  Widget _box(CfColors cf, double w, double h, {double radius = 6}) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: cf.sectionBackground,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
