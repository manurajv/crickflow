import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/cf_colors.dart';
import '../../../../../shared/widgets/cf_button.dart';
import '../../../services/stream_platform_service.dart';
import '../../providers/streaming_studio_providers.dart';

/// Connects the user's Google account for YouTube Live API (server-side token).
class StreamYouTubeLinkSection extends ConsumerStatefulWidget {
  const StreamYouTubeLinkSection({super.key, required this.matchId});

  final String matchId;

  @override
  ConsumerState<StreamYouTubeLinkSection> createState() =>
      _StreamYouTubeLinkSectionState();
}

class _StreamYouTubeLinkSectionState
    extends ConsumerState<StreamYouTubeLinkSection> {
  bool _linking = false;

  Future<void> _linkYouTube() async {
    setState(() => _linking = true);
    try {
      await ref.read(streamYouTubeAuthServiceProvider).linkYouTubeAccount();
      ref.invalidate(youtubeChannelsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('YouTube account linked')),
        );
      }
    } on StreamPlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('YouTube link failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final channelsAsync = ref.watch(youtubeChannelsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CfButton(
          compact: true,
          label: _linking ? 'Linking…' : 'Connect YouTube account',
          icon: Icons.account_circle,
          onPressed: _linking ? null : _linkYouTube,
        ),
        const SizedBox(height: 8),
        channelsAsync.when(
          data: (channels) {
            if (channels.isEmpty) {
              return Text(
                'Link your Google account to create live events automatically.',
                style: TextStyle(color: cf.textSecondary, fontSize: 11),
              );
            }
            return Text(
              'Linked: ${channels.first.title}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
