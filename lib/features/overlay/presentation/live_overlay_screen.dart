import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/cricket_math.dart';
import '../../../shared/providers/providers.dart';

/// Full-screen overlay view — mirrors broadcast graphics synced from Firestore.
class LiveOverlayScreen extends ConsumerWidget {
  const LiveOverlayScreen({super.key, required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overlayAsync = ref.watch(overlayProvider(matchId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: overlayAsync.when(
        data: (overlay) {
          if (overlay == null) {
            return const Center(child: Text('Waiting for live data...'));
          }

          return Stack(
            children: [
              // Sponsor banner area (top)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 48,
                  color: Colors.black54,
                  alignment: Alignment.center,
                  child: Text(
                    overlay.sponsorText.isNotEmpty
                        ? overlay.sponsorText
                        : 'CrickFlow Live',
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              // Main scorebug (bottom)
              Positioned(
                bottom: 32,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.scoreboardBg.withValues(alpha: 0.95),
                        AppColors.primaryBlue.withValues(alpha: 0.9),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.gold, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            overlay.battingTeamName,
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            color: AppColors.liveIndicator,
                            child: const Text(
                              'LIVE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${overlay.scoreDisplay} (${overlay.oversDisplay} ov)',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'RR ${overlay.runRate.toStringAsFixed(2)}'
                        '${overlay.requiredRunRate != null ? ' • RRR ${overlay.requiredRunRate!.toStringAsFixed(2)}' : ''}'
                        '${overlay.target != null ? ' • Target ${overlay.target}' : ''}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      const Divider(color: AppColors.border),
                      Row(
                        children: [
                          Expanded(
                            child: _batterLine(
                              '*${overlay.strikerName}',
                              overlay.strikerRuns,
                              overlay.strikerBalls,
                            ),
                          ),
                          Expanded(
                            child: _batterLine(
                              overlay.nonStrikerName,
                              overlay.nonStrikerRuns,
                              overlay.nonStrikerBalls,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${overlay.bowlerName} ${CricketMath.formatOvers(overlay.bowlerBalls, overlay.ballsPerOver)}-${overlay.bowlerRuns}-${overlay.bowlerWickets}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      if (overlay.locationLabel.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            overlay.locationLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }

  Widget _batterLine(String name, int runs, int balls) {
    final sr = CricketMath.strikeRate(runs, balls).toStringAsFixed(1);
    return Text(
      '$name $runs($balls) SR $sr',
      style: const TextStyle(color: Colors.white, fontSize: 13),
    );
  }
}
