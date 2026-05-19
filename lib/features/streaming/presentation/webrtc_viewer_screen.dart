import 'package:flutter/material.dart';
import 'package:crickflow/core/theme/app_dimens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/cf_button.dart';
import '../../../shared/widgets/multi_camera_watch_section.dart';

/// Low-latency viewer entry (signaling live; full WebRTC media in a follow-up).
class WebrtcViewerScreen extends ConsumerWidget {
  const WebrtcViewerScreen({super.key, required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchAsync = ref.watch(matchProvider(matchId));
    final roomAsync = ref.watch(webrtcRoomProvider(matchId));

    return Scaffold(
      appBar: AppBar(title: const Text('Low latency (beta)')),
      body: matchAsync.when(
        data: (match) {
          if (match == null) {
            return const Center(child: Text('Match not found'));
          }

          return ListView(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            children: [
              const Card(
                child: ListTile(
                  leading: Icon(Icons.speed, color: AppColors.gold),
                  title: Text('WebRTC beta'),
                  subtitle: Text(
                    'Signaling is active. Full peer video will ship in the next '
                    'release — use YouTube below or RTMP from Go Live today.',
                  ),
                ),
              ),
              roomAsync.when(
                data: (room) {
                  if (room == null || !room.isOpen) {
                    return const Card(
                      child: ListTile(
                        title: Text('Room not open'),
                        subtitle: Text(
                          'Broadcaster must enable WebRTC beta on Go Live.',
                        ),
                      ),
                    );
                  }
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.sensors, color: Colors.greenAccent),
                      title: const Text('Signaling room active'),
                      subtitle: Text(
                        'Publisher connected · ${room.viewerCount} viewer(s)',
                      ),
                    ),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
              ),
              const SizedBox(height: 12),
              MultiCameraWatchSection(
                primaryUrl: match.stream.youtubeWatchUrl,
                secondaryUrl: match.stream.secondaryYoutubeWatchUrl,
                primaryLabel: match.stream.cameraALabel,
                secondaryLabel: match.stream.cameraBLabel,
              ),
              const SizedBox(height: AppDimens.spaceMd),
              CfButton(
                label: 'Join signaling room',
                icon: Icons.login,
                isGold: true,
                onPressed: () async {
                  await ref.read(webrtcSignalingProvider).registerViewer(matchId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Registered as viewer')),
                    );
                  }
                },
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}
