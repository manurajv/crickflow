import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../domain/streaming_mode.dart';
import '../../presentation/providers/streaming_studio_providers.dart';

/// Native camera vs OBS / external encoder.
class StreamModeSelector extends ConsumerWidget {
  const StreamModeSelector({super.key, required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(streamStudioConfigProvider(matchId));
    final notifier = ref.read(streamStudioConfigProvider(matchId).notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Broadcast mode',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...StreamingMode.values.map((mode) {
              return RadioListTile<StreamingMode>(
                contentPadding: EdgeInsets.zero,
                title: Text(mode.label),
                subtitle: Text(
                  mode.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                value: mode,
                groupValue: config.streamingMode,
                onChanged: (v) {
                  if (v != null) {
                    notifier.update((c) => c.copyWith(streamingMode: v));
                  }
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}
