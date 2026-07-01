import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../streaming/presentation/providers/streaming_studio_providers.dart';
import '../../streaming/services/stream_platform_service.dart';
import 'widgets/match_highlights_list.dart';

class MatchHighlightsScreen extends ConsumerWidget {
  const MatchHighlightsScreen({super.key, required this.matchId});

  final String matchId;

  Future<void> _exportChapters(BuildContext context, WidgetRef ref) async {
    try {
      final export = await ref
          .read(streamPlatformServiceProvider)
          .exportYouTubeChapters(matchId);
      if (export == null || export.count == 0) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No replay markers to export yet')),
          );
        }
        return;
      }
      await Clipboard.setData(ClipboardData(text: export.chaptersText));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Copied ${export.count} chapter lines to clipboard'),
            action: SnackBarAction(
              label: 'Share',
              onPressed: () => Share.share(
                export.descriptionBlock,
                subject: 'YouTube chapters',
              ),
            ),
          ),
        );
      }
    } on StreamPlatformException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Match Highlights'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'Export YouTube chapters',
            onPressed: () => _exportChapters(context, ref),
          ),
        ],
      ),
      body: MatchHighlightsList(matchId: matchId),
    );
  }
}
