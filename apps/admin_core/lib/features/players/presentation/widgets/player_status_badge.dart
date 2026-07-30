import 'package:flutter/material.dart';

import '../../../../shared/widgets/cf_status_badge.dart';
import '../../models/player_enums.dart';

class PlayerStatusBadge extends StatelessWidget {
  const PlayerStatusBadge({super.key, required this.status});

  final ManagedPlayerStatus status;

  @override
  Widget build(BuildContext context) {
    final tone = switch (status) {
      ManagedPlayerStatus.verified => CfBadgeTone.success,
      ManagedPlayerStatus.active => CfBadgeTone.info,
      ManagedPlayerStatus.pendingVerification => CfBadgeTone.warning,
      ManagedPlayerStatus.suspended => CfBadgeTone.danger,
      ManagedPlayerStatus.archived => CfBadgeTone.neutral,
      ManagedPlayerStatus.deleted => CfBadgeTone.danger,
    };
    return CfStatusBadge(label: status.label, tone: tone, compact: true);
  }
}
