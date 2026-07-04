import 'package:flutter/material.dart';

import '../../../../core/theme/cf_colors.dart';

/// Non-blocking banner shown while RTMP is reconnecting after network loss.
class StreamReconnectingBanner extends StatelessWidget {
  const StreamReconnectingBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Material(
      color: cf.statusLive.withValues(alpha: 0.92),
      elevation: 2,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Reconnecting…',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
