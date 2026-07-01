import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../domain/destinations/stream_live_credentials.dart';
import '../../obs/obs_encoder_utils.dart';
import '../../studio/broadcast_session_controller.dart';

/// RTMP credentials + overlay browser source for OBS / external encoders.
class ObsSetupSection extends ConsumerWidget {
  const ObsSetupSection({
    super.key,
    required this.matchId,
    required this.credentials,
  });

  final String matchId;
  final StreamLiveCredentials? credentials;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final creds = credentials;
    final overlayUrl =
        BroadcastSessionController.overlayBrowserSourceUrl(matchId);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cf.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cf.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings_input_antenna_rounded, color: cf.accent),
                const SizedBox(width: 8),
                Text(
                  'OBS / External encoder',
                  style: TextStyle(
                    color: cf.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Add these in OBS → Settings → Stream. Use Browser Source for the live scoreboard overlay.',
              style: TextStyle(color: cf.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (creds == null)
              Text(
                'Configure platform and stream key in Setup, or link YouTube to auto-create.',
                style: TextStyle(color: cf.textMuted),
              )
            else ...[
              _CopyField(cf: cf, label: 'RTMP Server', value: creds.rtmpUrl),
              const SizedBox(height: 8),
              _CopyField(
                cf: cf,
                label: 'Stream Key',
                value: creds.streamKey,
                obscure: true,
              ),
              const SizedBox(height: 16),
              Center(
                child: QrImageView(
                  data: ObsEncoderUtils.qrPayload(creds),
                  size: 160,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Scan to import RTMP settings',
                  style: TextStyle(color: cf.textMuted, fontSize: 12),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _CopyField(cf: cf, label: 'Overlay browser source', value: overlayUrl),
            const SizedBox(height: 8),
            Text(
              'OBS: Add Browser Source → paste URL above → 1920×1080 → transparent background.',
              style: TextStyle(color: cf.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _CopyField extends StatelessWidget {
  const _CopyField({
    required this.cf,
    required this.label,
    required this.value,
    this.obscure = false,
  });

  final CfColors cf;
  final String label;
  final String value;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    final display = obscure && value.length > 8
        ? '${value.substring(0, 4)}…${value.substring(value.length - 4)}'
        : value;
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: value));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label copied')),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cf.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cf.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(color: cf.textMuted, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(
                    display,
                    style: TextStyle(
                      color: cf.textPrimary,
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.copy_rounded, size: 18, color: cf.textMuted),
          ],
        ),
      ),
    );
  }
}
