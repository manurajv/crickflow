import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rtmp_broadcaster/camera.dart';

import '../../../../../core/theme/cf_colors.dart';
import '../../../../../data/services/stream_service.dart';
import '../../../../../shared/providers/providers.dart';

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
    final preview = _buildPreview(context, cf, service);

    if (fill) return preview;
    return AspectRatio(aspectRatio: 16 / 9, child: preview);
  }

  Widget _buildPreview(
    BuildContext context,
    CfColors cf,
    StreamService service,
  ) {
    if (loading || !service.isInitialized) {
      return ColoredBox(
        color: Colors.black,
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
            ? RepaintBoundary(
                child: SizedBox.expand(
                  child: CameraPreview(controller),
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
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          previewChild,
          if (service.isInitialized)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: (details) async {
                  final box = context.findRenderObject() as RenderBox?;
                  if (box == null) return;
                  final local = box.globalToLocal(details.globalPosition);
                  final nx = (local.dx / box.size.width).clamp(0.0, 1.0);
                  final ny = (local.dy / box.size.height).clamp(0.0, 1.0);
                  await service.tapToFocus(nx, ny);
                },
              ),
            ),
        ],
      ),
    );
  }
}
