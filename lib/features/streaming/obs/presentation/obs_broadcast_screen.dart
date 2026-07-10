import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/cf_colors.dart';
import '../../domain/streaming_enums.dart';
import '../../studio/broadcast_session_controller.dart';

/// RTMP servers to surface for external encoders. Stream keys are entered in the
/// encoder / on the platform, never here.
const List<StreamPlatform> _kObsRtmpPlatforms = [
  StreamPlatform.youtube,
  StreamPlatform.facebook,
  StreamPlatform.twitch,
];

/// Full-screen, professional setup screen shown in the studio when the user
/// picks "OBS / external encoder". Presents the live scoreboard overlay browser
/// source and the RTMP server URLs for each platform (no stream key, no QR).
class ObsBroadcastScreen extends StatelessWidget {
  const ObsBroadcastScreen({
    super.key,
    required this.matchId,
    required this.onBack,
    this.isLive = false,
    this.onAddStreamLink,
    this.showStreamLinkDot = false,
    this.linkedStreamCount = 0,
  });

  final String matchId;
  final VoidCallback onBack;
  final bool isLive;
  final VoidCallback? onAddStreamLink;
  final bool showStreamLinkDot;
  final int linkedStreamCount;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final overlayUrl =
        BroadcastSessionController.overlayBrowserSourceUrl(matchId);

    return Material(
      color: cf.background,
      child: SafeArea(
        child: Column(
          children: [
            _Header(
              cf: cf,
              onBack: onBack,
              isLive: isLive,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _IntroCard(cf: cf),
                  const SizedBox(height: 16),
                  if (onAddStreamLink != null) ...[
                    _WatchLinkCard(
                      cf: cf,
                      linkedStreamCount: linkedStreamCount,
                      showStreamLinkDot: showStreamLinkDot,
                      onAddStreamLink: onAddStreamLink!,
                    ),
                    const SizedBox(height: 16),
                  ],
                  _OverlayCard(cf: cf, overlayUrl: overlayUrl),
                  const SizedBox(height: 16),
                  _RtmpServersCard(cf: cf),
                  const SizedBox(height: 16),
                  _StepsCard(cf: cf),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.cf,
    required this.onBack,
    this.isLive = false,
  });

  final CfColors cf;
  final VoidCallback onBack;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: cf.textPrimary),
            onPressed: onBack,
            tooltip: 'Back',
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'External Encoder',
                  style: TextStyle(
                    color: cf.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                Text(
                  'OBS · vMix · Streamlabs',
                  style: TextStyle(color: cf.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          if (isLive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cf.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: cf.error.withValues(alpha: 0.4)),
              ),
              child: Text(
                'LIVE',
                style: TextStyle(
                  color: cf.error,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WatchLinkCard extends StatelessWidget {
  const _WatchLinkCard({
    required this.cf,
    required this.linkedStreamCount,
    required this.showStreamLinkDot,
    required this.onAddStreamLink,
  });

  final CfColors cf;
  final int linkedStreamCount;
  final bool showStreamLinkDot;
  final VoidCallback onAddStreamLink;

  @override
  Widget build(BuildContext context) {
    final hasLink = linkedStreamCount > 0;
    return _SectionCard(
      cf: cf,
      icon: Icons.link_rounded,
      title: 'Public watch link',
      subtitle:
          'Paste the YouTube, Facebook, or Twitch URL where OBS is streaming '
          'so viewers can watch from the match scorecard. Add a new link after '
          'each reconnect.',
      accent: showStreamLinkDot,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasLink)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: cf.accent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      linkedStreamCount == 1
                          ? '1 stream linked for viewers'
                          : '$linkedStreamCount streams linked for viewers',
                      style: TextStyle(
                        color: cf.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          FilledButton.icon(
            onPressed: onAddStreamLink,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.add_link_rounded, size: 18),
                if (showStreamLinkDot)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: cf.error,
                        shape: BoxShape.circle,
                        border: Border.all(color: cf.surface, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            label: Text(hasLink ? 'Add another stream link' : 'Add stream link'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.cf});

  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cf.accent.withValues(alpha: 0.18),
            cf.accent.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cf.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cf.accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.settings_input_antenna_rounded,
                color: cf.accent, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stream from your encoder',
                  style: TextStyle(
                    color: cf.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add the scoreboard overlay as a browser source and point '
                  'your encoder at your platform. Enter your stream key in the '
                  'encoder — not here.',
                  style: TextStyle(
                    color: cf.textSecondary,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlayCard extends StatelessWidget {
  const _OverlayCard({required this.cf, required this.overlayUrl});

  final CfColors cf;
  final String overlayUrl;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      cf: cf,
      icon: Icons.dashboard_customize_rounded,
      title: 'Live scoreboard overlay',
      subtitle:
          'Add this as a Browser Source in your encoder (1920×1080, transparent '
          'background). The live scorebug — score, batters, bowler, run-rate and '
          'target chips — renders here and updates in real time as you score.',
      accent: true,
      child: _CopyField(cf: cf, label: 'Browser source URL', value: overlayUrl),
    );
  }
}

class _RtmpServersCard extends StatelessWidget {
  const _RtmpServersCard({required this.cf});

  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      cf: cf,
      icon: Icons.dns_rounded,
      title: 'RTMP servers',
      subtitle:
          'Paste the server for your platform into your encoder, then add the '
          'stream key from that platform.',
      child: Column(
        children: [
          for (final platform in _kObsRtmpPlatforms) ...[
            _CopyField(
              cf: cf,
              label: platform.label,
              value: platform.defaultRtmpUrl,
              leadingIcon: _platformIcon(platform),
            ),
            if (platform != _kObsRtmpPlatforms.last)
              const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  static IconData _platformIcon(StreamPlatform platform) => switch (platform) {
        StreamPlatform.youtube => Icons.play_circle_outline,
        StreamPlatform.facebook => Icons.facebook,
        StreamPlatform.twitch => Icons.videogame_asset_outlined,
        StreamPlatform.customRtmp => Icons.settings_input_antenna,
      };
}

class _StepsCard extends StatelessWidget {
  const _StepsCard({required this.cf});

  final CfColors cf;

  static const _steps = [
    'In your platform (YouTube/Facebook), create a live event and copy its '
        'stream key.',
    'In OBS → Settings → Stream, pick Custom, paste the RTMP server above and '
        'your stream key.',
    'In OBS, add a Browser Source with the overlay URL above (1920×1080, '
        'transparent).',
    'Start streaming in OBS, then tap Add stream link above and paste the '
        'public watch URL from your platform.',
    'The scoreboard overlay updates live automatically as you score.',
  ];

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      cf: cf,
      icon: Icons.checklist_rounded,
      title: 'How to go live',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _steps.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == _steps.length - 1 ? 0 : 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cf.accent.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: cf.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _steps[i],
                        style: TextStyle(
                          color: cf.textSecondary,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.cf,
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
    this.accent = false,
  });

  final CfColors cf;
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cf.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent ? cf.accent.withValues(alpha: 0.5) : cf.border,
          width: accent ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent ? cf.accent : cf.textSecondary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: cf.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: TextStyle(
                color: cf.textSecondary,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _CopyField extends StatelessWidget {
  const _CopyField({
    required this.cf,
    required this.label,
    required this.value,
    this.leadingIcon,
  });

  final CfColors cf;
  final String label;
  final String value;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: value));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label URL copied')),
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cf.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cf.border),
        ),
        child: Row(
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon, size: 18, color: cf.textSecondary),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(color: cf.textMuted, fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
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
            const SizedBox(width: 8),
            Icon(Icons.copy_rounded, size: 18, color: cf.accent),
          ],
        ),
      ),
    );
  }
}

