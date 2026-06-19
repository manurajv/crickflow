import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/player_model.dart';
import '../../../../data/models/team_model.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/providers/team_join_request_provider.dart';
import '../utils/team_squad_utils.dart';
import '../../../../shared/widgets/cf_button.dart';

/// Sends a join request to the team owner (or shows pending state).
Future<bool> sendTeamJoinRequest({
  required WidgetRef ref,
  required BuildContext context,
  required TeamModel team,
}) async {
  final uid = ref.read(authStateProvider).value?.uid;
  final profile = ref.read(currentUserProfileProvider).valueOrNull;
  if (uid == null) return false;

  if (profile?.role == UserRole.viewer) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Switch to Player role to join a team'),
        ),
      );
    }
    return false;
  }

  try {
    final player = await ref.read(playerRepositoryProvider).ensurePlayerProfileForUser(
          userId: uid,
          displayName: profile?.displayName ?? 'Player',
          fullName: profile?.name,
          photoUrl: profile?.photoUrl,
          email: profile?.email,
          playerId: profile?.playerId,
        );

    await ref.read(teamJoinRequestRepositoryProvider).createRequest(
          team: team,
          player: player,
          profile: profile,
        );

    ref.invalidate(userTeamJoinRequestProvider((
      teamId: team.id,
      userId: uid,
    )));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Join request sent to ${team.name}'),
        ),
      );
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send request: $e')),
      );
    }
    return false;
  }
}

class TeamJoinActionButton extends ConsumerStatefulWidget {
  const TeamJoinActionButton({
    super.key,
    required this.team,
    this.compact = false,
    this.onRequested,
  });

  final TeamModel team;
  final bool compact;
  final VoidCallback? onRequested;

  @override
  ConsumerState<TeamJoinActionButton> createState() =>
      _TeamJoinActionButtonState();
}

class _TeamJoinActionButtonState extends ConsumerState<TeamJoinActionButton> {
  var _submitting = false;

  Future<void> _requestJoin() async {
    setState(() => _submitting = true);
    try {
      await sendTeamJoinRequest(
        ref: ref,
        context: context,
        team: widget.team,
      );
      widget.onRequested?.call();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authStateProvider).value?.uid;
    if (uid == null) return const SizedBox.shrink();

    final requestAsync = ref.watch(
      userTeamJoinRequestProvider((teamId: widget.team.id, userId: uid)),
    );
    final request = requestAsync.valueOrNull;

    if (request?.isPending == true) {
      if (widget.compact) {
        final cf = context.cf;
        return TextButton(
          onPressed: null,
          child: Text(
            'Requested',
            style: TextStyle(color: cf.textMuted),
          ),
        );
      }
      return CfButton(
        label: 'Request pending',
        icon: Icons.hourglass_top,
        onPressed: null,
      );
    }

    if (widget.compact) {
      final cf = context.cf;
      return TextButton(
        onPressed: _submitting ? null : _requestJoin,
        style: TextButton.styleFrom(foregroundColor: cf.link),
        child: _submitting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Join'),
      );
    }

    return CfButton(
      label: _submitting ? 'Sending…' : 'Request to join',
      icon: Icons.group_add,
      isGold: true,
      onPressed: _submitting ? null : _requestJoin,
    );
  }
}

/// Whether the signed-in user can request to join [team].
bool canRequestJoinTeam({
  required TeamModel team,
  required String? uid,
  required List<PlayerModel> squad,
}) {
  if (uid == null || uid.isEmpty) return false;
  if (TeamSquadUtils.isTeamOwner(uid, team)) return false;
  if (TeamSquadUtils.isTeamCaptain(uid, team)) return false;
  if (TeamSquadUtils.isTeamViceCaptain(uid, team)) return false;
  if (TeamSquadUtils.isOnSquad(uid, team, squad)) return false;
  return true;
}
