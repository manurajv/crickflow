import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/country_flag_utils.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/tournament_model.dart';

class TournamentListCard extends StatelessWidget {
  const TournamentListCard({
    super.key,
    required this.tournament,
    this.onTap,
    this.trailing,
  });

  final TournamentModel tournament;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final status = _statusLabel(tournament.status);

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceXs,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                _Banner(tournament: tournament),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _VenueCountryFlag(
                        country: tournament.location.country,
                      ),
                      _StatusBadge(
                        label: status.label,
                        color: status.color,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: AppDimens.cardPadding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_dateLine(tournament).isNotEmpty)
                          Text(
                            _dateLine(tournament),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (tournament.location.displayLabel.isNotEmpty)
                          Text(
                            tournament.location.displayLabel,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        Text(
                          '${tournament.teamIds.length} teams · ${tournament.matchIds.length} matches',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  trailing ??
                      Text(
                        tournament.format.name,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: AppColors.primaryBlueLight,
                            ),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _dateLine(TournamentModel t) {
    if (t.startDate == null && t.endDate == null) return '';
    final start = t.startDate != null
        ? AppDateUtils.formatShort(t.startDate!)
        : '';
    final end =
        t.endDate != null ? AppDateUtils.formatShort(t.endDate!) : '';
    if (start.isEmpty) return end;
    if (end.isEmpty) return start;
    return '$start to $end';
  }

  ({String label, Color color}) _statusLabel(TournamentStatus status) {
    return switch (status) {
      TournamentStatus.live => (
          label: 'Ongoing',
          color: AppColors.liveIndicator,
        ),
      TournamentStatus.upcoming => (label: 'Upcoming', color: AppColors.gold),
      TournamentStatus.completed => (
          label: 'Completed',
          color: AppColors.primaryBlueLight,
        ),
      TournamentStatus.cancelled => (
          label: 'Cancelled',
          color: AppColors.textMuted,
        ),
      TournamentStatus.draft => (
          label: 'Draft',
          color: AppColors.textMuted,
        ),
    };
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.tournament});

  final TournamentModel tournament;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (tournament.bannerUrl != null)
            CachedNetworkImage(
              imageUrl: tournament.bannerUrl!,
              fit: BoxFit.cover,
            )
          else
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A2744), AppColors.primaryBlue],
                ),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.75),
                ],
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 10,
            child: Text(
              tournament.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _VenueCountryFlag extends StatelessWidget {
  const _VenueCountryFlag({required this.country});

  final String country;

  @override
  Widget build(BuildContext context) {
    final flag = CountryFlagUtils.flagForCountry(country);
    if (flag.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Text(
        flag,
        style: const TextStyle(fontSize: 13),
      ),
    );
  }
}
