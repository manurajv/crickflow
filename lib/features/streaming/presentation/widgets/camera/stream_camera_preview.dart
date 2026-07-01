import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rtmp_broadcaster/camera.dart';

import '../../../../../core/theme/cf_colors.dart';
import '../../../../../data/services/stream_service.dart';
import '../../../../../shared/providers/providers.dart';
import '../../providers/streaming_studio_providers.dart';

class StreamCameraPreview extends ConsumerWidget {
  const StreamCameraPreview({
    super.key,
    required this.matchId,
    this.loading = false,
    this.error,
    this.fill = true,
  });

  final String matchId;
  final bool loading;
  final String? error;
  final bool fill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final service = ref.watch(streamServiceProvider);
    final tapToFocus = ref.watch(
      streamStudioConfigProvider(matchId).select(
        (c) => c.cameraControls.tapToFocusEnabled,
      ),
    );
    final preview = _buildPreview(context, cf, service, tapToFocus);

    if (fill) return preview;
    return AspectRatio(aspectRatio: 16 / 9, child: preview);
  }

  Widget _buildPreview(
    BuildContext context,
    CfColors cf,
    StreamService service,
    bool tapToFocusEnabled,
  ) {
    if (loading || !service.isInitialized) {
      return ColoredBox(
        color: cf.background,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: cf.accent),
              const SizedBox(height: 12),
              Text(
                'Starting camera…',
                style: TextStyle(color: cf.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    final controller = service.cameraController;
    final previewChild =
        controller != null && controller.value.isInitialized == true
            ? SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: controller.value.previewSize?.width ?? 1280,
                    height: controller.value.previewSize?.height ?? 720,
                    child: CameraPreview(controller),
                  ),
                ),
              )
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    error ?? service.lastError ?? 'Camera unavailable',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cf.textSecondary),
                  ),
                ),
              );

    return ColoredBox(
      color: cf.background,
      child: tapToFocusEnabled && service.isInitialized
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) async {
                final box = context.findRenderObject() as RenderBox?;
                if (box == null) return;
                final local = box.globalToLocal(details.globalPosition);
                final nx = (local.dx / box.size.width).clamp(0.0, 1.0);
                final ny = (local.dy / box.size.height).clamp(0.0, 1.0);
                await service.tapToFocus(nx, ny);
              },
              child: previewChild,
            )
          : previewChild,
    );
  }
}
