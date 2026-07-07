import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/cf_colors.dart';
import '../../../../../data/services/stream_service.dart';
import '../../../../../shared/providers/providers.dart';
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

  Future<void> _recoverCameraAfterOAuth() async {
    if (!mounted) return;
    final service = ref.read(streamServiceProvider);
    if (!StreamService.isPlatformSupported || !service.isInitialized) return;
    try {
      await service.recoverPreview();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _applyLinkedChannel() async {
    if (!mounted) return;
    final channels =
        await ref.read(streamPlatformServiceProvider).fetchYouTubeChannels();
    if (!mounted || channels.isEmpty) return;

    final notifier =
        ref.read(streamStudioConfigProvider(widget.matchId).notifier);
    final linked = channels.first;
    // Always apply the newly linked account — switching Google accounts must
    // replace the previous channel and clear stale broadcast metadata.
    notifier.update(
      (c) => c.copyWith(
        youtubeChannelId: linked.id,
        youtubeChannelName: linked.title,
        youtubeBroadcastId: '',
        youtubeStreamId: '',
        youtubeWatchUrl: '',
      ),
    );
    ref.invalidate(youtubeChannelsProvider);
    await ref.read(youtubeChannelsProvider.future);
    await persistStudioConfigPreferences(ref, widget.matchId);
  }

  Future<void> _linkYouTube() async {
    setState(() => _linking = true);
    try {
      await ref.read(streamYouTubeAuthServiceProvider).linkYouTubeAccount();
      await _applyLinkedChannel();
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
      if (mounted) {
        await _recoverCameraAfterOAuth();
        setState(() => _linking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final config = ref.watch(streamStudioConfigProvider(widget.matchId));
    final channelsAsync = ref.watch(youtubeChannelsProvider);
    final hasLinkedAccount = channelsAsync.valueOrNull?.isNotEmpty == true ||
        config.youtubeChannelId.isNotEmpty;

    ref.listen<AsyncValue<List<YouTubeChannel>>>(
      youtubeChannelsProvider,
      (_, next) {
        syncYouTubeChannelToStudioConfig(
          ref,
          widget.matchId,
          channels: next.valueOrNull,
        );
      },
    );
    final channelsNow = channelsAsync.valueOrNull;
    if (channelsNow != null && channelsNow.isNotEmpty) {
      syncYouTubeChannelToStudioConfig(
        ref,
        widget.matchId,
        channels: channelsNow,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CfButton(
          compact: true,
          label: _linking
              ? 'Linking…'
              : hasLinkedAccount
                  ? 'Connect another account'
                  : 'Connect YouTube account',
          icon: Icons.account_circle,
          onPressed: _linking ? null : _linkYouTube,
        ),
        const SizedBox(height: 8),
        channelsAsync.when(
          data: (channels) {
            if (!hasLinkedAccount) {
              return Text(
                'Link your Google account to create live events automatically.',
                style: TextStyle(color: cf.textSecondary, fontSize: 11),
              );
            }
            final label = config.youtubeChannelName.isNotEmpty
                ? config.youtubeChannelName
                : channels.isNotEmpty
                    ? channels.first.title
                    : 'YouTube channel';
            return Text(
              'Linked: $label',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            );
          },
          loading: () => Text(
            _linking ? 'Finishing YouTube link…' : 'Loading channels…',
            style: TextStyle(color: cf.textSecondary, fontSize: 11),
          ),
          error: (error, _) => Text(
            error is StreamPlatformException
                ? error.message
                : 'Could not load YouTube channels: $error',
            style: TextStyle(color: cf.error, fontSize: 11),
          ),
        ),
      ],
    );
  }
}
