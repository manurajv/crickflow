import 'package:flutter/material.dart';
import 'package:crickflow/core/theme/app_dimens.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/streaming/match_stream_playback.dart';
import 'match_stream_player.dart';

/// Two YouTube angles (main + secondary) for Phase 3.4 multi-camera.
class MultiCameraWatchSection extends StatefulWidget {
  const MultiCameraWatchSection({
    super.key,
    required this.primaryUrl,
    this.secondaryUrl,
    this.primaryLabel = 'Main camera',
    this.secondaryLabel = 'Camera 2',
  });

  final String? primaryUrl;
  final String? secondaryUrl;
  final String primaryLabel;
  final String secondaryLabel;

  @override
  State<MultiCameraWatchSection> createState() => _MultiCameraWatchSectionState();
}

class _MultiCameraWatchSectionState extends State<MultiCameraWatchSection> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final primary = widget.primaryUrl?.trim();
    final secondary = widget.secondaryUrl?.trim();
    final sources = <MatchStreamSource>[];
    if (primary != null && primary.isNotEmpty) {
      sources.add(MatchStreamSource(
        url: primary,
        label: widget.primaryLabel,
        platform: MatchStreamPlayback.platformFromUrl(primary),
      ));
    }
    if (secondary != null && secondary.isNotEmpty) {
      sources.add(MatchStreamSource(
        url: secondary,
        label: widget.secondaryLabel,
        platform: MatchStreamPlayback.platformFromUrl(secondary),
      ));
    }

    if (sources.isEmpty) {
      return const SizedBox.shrink();
    }

    if (sources.length == 1) {
      return MatchStreamPlayer(source: sources.first);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
          child: SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 0, label: Text(widget.primaryLabel)),
              ButtonSegment(value: 1, label: Text(widget.secondaryLabel)),
            ],
            selected: {_index},
            onSelectionChanged: (s) => setState(() => _index = s.first),
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.black;
                }
                return AppColors.textSecondary;
              }),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.gold;
                }
                return AppColors.surface;
              }),
            ),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: MatchStreamPlayer(
            key: ValueKey(_index == 0 ? 'cam-a' : 'cam-b'),
            source: sources[_index],
          ),
        ),
      ],
    );
  }
}
