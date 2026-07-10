import 'package:flutter/material.dart';

/// App-bar control to show or hide the scorecard live stream player.
class StreamLiveToggleAction extends StatelessWidget {
  const StreamLiveToggleAction({
    super.key,
    required this.visible,
    required this.onToggle,
  });

  final bool visible;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final on = visible;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: TextButton(
        onPressed: onToggle,
        style: TextButton.styleFrom(
          foregroundColor: on ? theme.colorScheme.error : theme.colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          on ? 'Live on' : 'Live off',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
    );
  }
}
