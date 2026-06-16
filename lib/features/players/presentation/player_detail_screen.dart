import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/cricket_math.dart';
import '../../../shared/providers/badge_provider.dart';
import '../../../shared/widgets/badge_gallery.dart';
import '../../../domain/wagon_wheel/wagon_wheel_filter.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';
import '../../wagon_wheel/presentation/widgets/wagon_wheel_embedded_section.dart';

class PlayerDetailScreen extends ConsumerWidget {
  const PlayerDetailScreen({super.key, required this.playerId});

  final String playerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerAsync = ref.watch(playerDetailProvider(playerId));

    return Scaffold(
      appBar: const CfChromeAppBar(title: Text('Player')),
      body: playerAsync.when(
        data: (player) {
          if (player == null) {
            return const Center(child: Text('Player not found'));
          }

          final sr = CricketMath.strikeRate(
            player.stats.runs,
            player.stats.ballsFaced,
          );
          final economy = CricketMath.economyRate(
            player.stats.runsConceded,
            player.stats.oversBowledBalls,
            6,
          );

          return ListView(
            padding: AppDimens.listPadding,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.primaryBlue,
                  backgroundImage: player.photoUrl != null
                      ? CachedNetworkImageProvider(player.photoUrl!)
                      : null,
                  child: player.photoUrl == null
                      ? Text(
                          player.name.isNotEmpty
                              ? player.name[0].toUpperCase()
                              : '?',
                          style: Theme.of(context).textTheme.displayLarge,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              Text(
                player.name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (player.playerId != null && player.playerId!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    player.playerId!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                  ),
                ),
              if (player.role.isNotEmpty)
                Text(
                  player.role,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              if (player.location.displayLabel.isNotEmpty)
                Text(
                  player.location.displayLabel,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: AppDimens.spaceLg),
              Text('Batting', style: Theme.of(context).textTheme.titleLarge),
              _statTile(context, 'Runs', '${player.stats.runs}'),
              _statTile(context, 'Strike rate', sr.toStringAsFixed(1)),
              _statTile(context, 'Fours / Sixes',
                  '${player.stats.fours} / ${player.stats.sixes}'),
              const SizedBox(height: AppDimens.spaceMd),
              Text('Bowling', style: Theme.of(context).textTheme.titleLarge),
              _statTile(context, 'Wickets', '${player.stats.wickets}'),
              _statTile(context, 'Economy', economy.toStringAsFixed(2)),
              const SizedBox(height: AppDimens.spaceMd),
              WagonWheelEmbeddedSection(
                title: 'Batting wagon wheel',
                fullViewTitle: '${player.name} — batting',
                baseFilter: WagonWheelFilter(batterId: playerId),
              ),
              if (player.stats.wickets > 0) ...[
                const SizedBox(height: AppDimens.spaceMd),
                WagonWheelEmbeddedSection(
                  title: 'Bowling wagon wheel',
                  fullViewTitle: '${player.name} — conceded',
                  baseFilter: WagonWheelFilter(bowlerId: playerId),
                  showWhenEmpty: false,
                ),
              ],
              const SizedBox(height: AppDimens.spaceMd),
              Text('Career', style: Theme.of(context).textTheme.titleLarge),
              _statTile(
                  context, 'Matches', '${player.stats.matchesPlayed}'),
              if (player.badgeIds.isNotEmpty) ...[
                const SizedBox(height: AppDimens.spaceMd),
                Text('Badges', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppDimens.spaceSm),
                BadgeGallery(badgeIds: player.badgeIds),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }

  Widget _statTile(BuildContext context, String label, String value) {
    return ListTile(
      dense: true,
      title: Text(label),
      trailing: Text(
        value,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.gold,
            ),
      ),
    );
  }
}
