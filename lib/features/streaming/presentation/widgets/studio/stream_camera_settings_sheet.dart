import 'package:flutter/material.dart';

import '../../../../../core/theme/cf_colors.dart';
import '../../../camera/presentation/professional_camera_panel.dart';

/// Exposure, focus, and white balance — opened from the studio overlay.
Future<void> showStreamCameraSettingsSheet(
  BuildContext context, {
  required String matchId,
  required bool cameraReady,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.3,
      maxChildSize: 0.75,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: context.cf.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(top: BorderSide(color: context.cf.border)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.cf.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Camera',
                        style: TextStyle(
                          color: context.cf.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Done', style: TextStyle(color: context.cf.accent)),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: context.cf.border),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                  children: [
                    ProfessionalCameraPanel(
                      matchId: matchId,
                      enabled: cameraReady,
                      showTorch: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
