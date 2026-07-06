import 'package:flutter/material.dart';

import '../../../../data/models/post_match_snapshot.dart';
import '../../../../data/models/stream_overlay_theme.dart';
import '../innings_break/innings_break_screens.dart';
import 'post_match_snapshot_adapter.dart';

/// Thank-you card shown after the 10s match summary until live ends.
class PostMatchThankYouScreen extends StatelessWidget {
  const PostMatchThankYouScreen({
    super.key,
    required this.snapshot,
    required this.theme,
    required this.landscape,
  });

  final PostMatchSnapshot snapshot;
  final StreamOverlayTheme theme;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    return ThankYouScreen(
      snapshot: PostMatchSnapshotAdapter.shellSnapshot(snapshot),
      theme: theme,
      landscape: landscape,
      subtitle: 'Thank You',
    );
  }
}
