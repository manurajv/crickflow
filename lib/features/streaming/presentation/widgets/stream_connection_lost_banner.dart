import 'package:flutter/material.dart';

import '../../../../core/theme/cf_colors.dart';

/// Non-blocking banner when RTMP reconnect attempts are exhausted.
class StreamConnectionLostBanner extends StatelessWidget {
  const StreamConnectionLostBanner({
    super.key,
    required this.onRetry,
    required this.onEndStream,
  });

  final VoidCallback onRetry;
  final VoidCallback onEndStream;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Material(
      color: cf.error.withValues(alpha: 0.92),
      elevation: 4,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Connection lost.',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Unable to reconnect.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Retry'),
              ),
              TextButton(
                onPressed: onEndStream,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('End Stream'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
