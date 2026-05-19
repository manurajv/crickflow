import 'package:flutter/material.dart';
import 'package:crickflow/core/theme/app_dimens.dart';
import '../../core/theme/app_colors.dart';
import 'youtube_embed_card.dart';

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

  bool get _hasSecondary =>
      widget.secondaryUrl != null && widget.secondaryUrl!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!_hasSecondary) {
      return YoutubeEmbedCard(youtubeWatchUrl: widget.primaryUrl);
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
          child: _index == 0
              ? YoutubeEmbedCard(
                  key: const ValueKey('cam-a'),
                  youtubeWatchUrl: widget.primaryUrl,
                )
              : YoutubeEmbedCard(
                  key: const ValueKey('cam-b'),
                  youtubeWatchUrl: widget.secondaryUrl,
                ),
        ),
      ],
    );
  }
}
