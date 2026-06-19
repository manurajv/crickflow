import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../core/utils/cf_team_id_format.dart';
import '../../../../core/utils/team_invite_utils.dart';
import '../../../../data/models/team_model.dart';
import '../../../../shared/providers/providers.dart';
import 'team_qr_view.dart';

/// Invite card: QR, team ID, link, copy & share actions.
class TeamInviteShareCard extends ConsumerStatefulWidget {
  const TeamInviteShareCard({super.key, required this.team});

  final TeamModel team;

  @override
  ConsumerState<TeamInviteShareCard> createState() =>
      _TeamInviteShareCardState();
}

class _TeamInviteShareCardState extends ConsumerState<TeamInviteShareCard> {
  TeamModel? _resolved;
  var _loadingQr = false;

  TeamModel get _team => _resolved ?? widget.team;

  @override
  void initState() {
    super.initState();
    _ensureQr();
  }

  @override
  void didUpdateWidget(covariant TeamInviteShareCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.team.id != widget.team.id) {
      _resolved = null;
      _ensureQr();
    }
  }

  Future<void> _ensureQr() async {
    if (_team.qrUrl != null && _team.qrUrl!.isNotEmpty) return;
    setState(() => _loadingQr = true);
    final updated = await ref.read(teamRepositoryProvider).ensureTeamQr(_team);
    if (mounted) {
      setState(() {
        _resolved = updated ?? _team;
        _loadingQr = false;
      });
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _copyLink() async {
    await TeamInviteUtils.copyLink(_team);
    _snack('Invite link copied');
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final link = TeamInviteUtils.inviteLink(_team);
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: cf.sectionBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cf.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: cf.accent.withValues(alpha: 0.12),
                  child: Icon(
                    Icons.group_add_outlined,
                    color: cf.accent,
                  ),
                ),
                const SizedBox(width: AppDimens.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invite your squad',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cf.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Share the link or QR — players can join ${_team.name} in CrickFlow.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cf.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceLg),
            Center(
              child: _loadingQr
                  ? const SizedBox(
                      width: 180,
                      height: 180,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : TeamQrView(team: _team, size: 180, showTeamCode: false),
            ),
            if (_team.teamCode != null && _team.teamCode!.isNotEmpty) ...[
              const SizedBox(height: AppDimens.spaceSm),
              Center(
                child: Text(
                  'Team ID · ${CfTeamIdFormat.displayLabel(_team.teamCode)}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: cf.link,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppDimens.spaceLg),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
                vertical: AppDimens.spaceSm,
              ),
              decoration: BoxDecoration(
                color: cf.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cf.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      link,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cf.textMuted,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy link',
                    onPressed: _copyLink,
                    icon: Icon(Icons.copy_outlined, size: 20, color: cf.link),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => TeamInviteUtils.shareLink(_team),
                    icon: const Icon(Icons.ios_share_outlined, size: 18),
                    label: const Text('Share'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      foregroundColor: cf.link,
                      side: BorderSide(color: cf.accent.withValues(alpha: 0.55)),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimens.spaceSm),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => TeamInviteUtils.shareWhatsApp(_team),
                    icon: const Icon(Icons.chat_outlined, size: 18),
                    label: const Text('WhatsApp'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
