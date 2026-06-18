import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/cf_player_id_format.dart';
import '../../../../core/utils/match_display_id.dart';
import '../../../../core/utils/match_permissions.dart';
import '../../../../core/utils/scorer_qr_utils.dart';
import '../../../../data/models/match_model.dart';
import '../../../../data/models/match_setup_draft_models.dart';
import '../../../../data/models/player_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/scoring_ui_kit.dart';

enum _ChangeScorerTab { qrCode, teams, officials, search }

/// Change active scorer — QR, team players, officials, or user search.
class ChangeScorerSheet extends ConsumerStatefulWidget {
  const ChangeScorerSheet({
    super.key,
    required this.match,
  });

  final MatchModel match;

  static Future<void> show(BuildContext context, MatchModel match) {
    return ScoringUiKit.showDraggableSheet<void>(
      context,
      initialChildSize: 0.82,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (_, __) => ChangeScorerSheet(match: match),
    );
  }

  @override
  ConsumerState<ChangeScorerSheet> createState() => _ChangeScorerSheetState();
}

class _ChangeScorerSheetState extends ConsumerState<ChangeScorerSheet> {
  _ChangeScorerTab _tab = _ChangeScorerTab.qrCode;
  bool _teamA = true;
  String? _qrPayload;
  bool _loadingQr = false;

  final _searchController = TextEditingController();
  List<UserModel> _searchResults = [];
  List<PlayerModel> _playerResults = [];
  bool _searching = false;
  String? _searchError;
  bool _transferring = false;
  int _replaceSlotIndex = 1;

  @override
  void initState() {
    super.initState();
    _loadQr();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadQr() async {
    setState(() => _loadingQr = true);
    try {
      final token = await ref
          .read(matchRepositoryProvider)
          .ensureScorerOwnershipToken(widget.match.id);
      if (mounted) {
        setState(() {
          _qrPayload = ScorerQrUtils.buildTakeoverUri(
            matchDocumentId: widget.match.id,
            ownershipToken: token,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load QR: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingQr = false);
    }
  }

  Future<void> _searchUsers() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _searching = true;
      _searchError = null;
      _searchResults = [];
      _playerResults = [];
    });

    try {
      final users =
          await ref.read(userRepositoryProvider).searchScorers(query);
      final players = await ref
          .read(playerRepositoryProvider)
          .searchPlayersDirectory(query: query);
      if (mounted) {
        setState(() {
          _searchResults = users;
          _playerResults = players;
          if (users.isEmpty && players.isEmpty) {
            _searchError = 'No player found';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _searchError = 'Search failed: $e');
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _replaceWithPlayer(PlayerModel player) async {
    final userId = player.userId;
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This player has no linked account — choose another player',
          ),
        ),
      );
      return;
    }

    final confirmed = await ScoringUiKit.confirmAction(
      context,
      title: 'Change scorer',
      message:
          'Assign ${player.name} as Scorer ${_replaceSlotIndex + 1}?',
      confirmLabel: 'Confirm',
      cancelLabel: 'Cancel',
    );
    if (confirmed != true || !mounted) return;

    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    if (uid == null) return;

    setState(() => _transferring = true);
    try {
      await ref.read(matchRepositoryProvider).replaceAssignedScorer(
            matchId: widget.match.id,
            slotIndex: _replaceSlotIndex,
            replacement: MatchOfficialEntry(
              userId: userId,
              playerId: player.playerId ?? player.id,
              name: player.name,
              photoUrl: player.photoUrl,
              slotLabel: _replaceSlotIndex == 0 ? 'Scorer 1' : 'Scorer 2',
            ),
            actorUserId: uid,
            actorName: profile?.displayName ?? 'Scorer',
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${player.name} is now Scorer ${_replaceSlotIndex + 1}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not change scorer: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _transferring = false);
    }
  }

  Future<void> _confirmTransfer({
    required String toUserId,
    required String toUserName,
    String? toUserPhoto,
  }) async {
    final confirmed = await ScoringUiKit.confirmAction(
      context,
      title: 'Transfer scoring',
      message: 'Transfer scoring to:\n\n$toUserName',
      confirmLabel: 'Confirm',
      cancelLabel: 'Cancel',
    );
    if (confirmed != true || !mounted) return;

    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    if (uid == null) return;

    setState(() => _transferring = true);
    try {
      await ref.read(matchRepositoryProvider).transferScorerOwnership(
            matchId: widget.match.id,
            fromUserId: uid,
            fromUserName: profile?.displayName ?? 'Scorer',
            toUserId: toUserId,
            toUserName: toUserName,
            toUserPhoto: toUserPhoto,
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scoring transferred to $toUserName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transfer failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _transferring = false);
    }
  }

  Future<void> _transferToPlayer(PlayerModel player) async {
    final userId = player.userId;
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This player has no linked account — use Search or QR instead',
          ),
        ),
      );
      return;
    }
    await _confirmTransfer(
      toUserId: userId,
      toUserName: player.name,
      toUserPhoto: player.photoUrl,
    );
  }

  Future<void> _transferToOfficial(MatchOfficialEntry official) async {
    final userId = official.userId;
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This official has no linked account — use Search or QR instead',
          ),
        ),
      );
      return;
    }
    await _confirmTransfer(
      toUserId: userId,
      toUserName: official.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return SafeArea(
      child: Column(
        children: [
          if (!keyboardOpen) const ScoringSheetHeader(title: 'Change scorer'),
          if (keyboardOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                AppDimens.spaceSm,
                AppDimens.spaceMd,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Change scorer',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  ScoringUiKit.sheetCloseButton(context),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
            child: _RadioTabBar(
              selected: _tab,
              onSelected: (t) => setState(() => _tab = t),
            ),
          ),
          SizedBox(height: keyboardOpen ? AppDimens.spaceSm : AppDimens.spaceMd),
          Expanded(
            child: _transferring
                ? const Center(child: CircularProgressIndicator())
                : _buildTabContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    final currentScorerId = effectiveScorerId(widget.match);
    switch (_tab) {
      case _ChangeScorerTab.qrCode:
        return _QrTab(
          loading: _loadingQr,
          payload: _qrPayload,
          displayId: MatchDisplayId.of(widget.match.id),
        );
      case _ChangeScorerTab.teams:
        return _TeamsTab(
          match: widget.match,
          teamA: _teamA,
          currentScorerId: currentScorerId,
          onTeamChanged: (a) => setState(() => _teamA = a),
          onPlayerTap: _transferToPlayer,
        );
      case _ChangeScorerTab.officials:
        return _OfficialsTab(
          match: widget.match,
          currentScorerId: currentScorerId,
          onOfficialTap: _transferToOfficial,
          onAddOfficials: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Match officials are added during match setup before going live',
                ),
              ),
            );
            context.push('/match/${widget.match.id}');
          },
        );
      case _ChangeScorerTab.search:
        return _SearchTab(
          controller: _searchController,
          searching: _searching,
          error: _searchError,
          results: _searchResults,
          playerResults: _playerResults,
          replaceSlotIndex: _replaceSlotIndex,
          onReplaceSlotChanged: (i) => setState(() => _replaceSlotIndex = i),
          currentScorerId: currentScorerId,
          onSearch: _searchUsers,
          onUserTap: (u) => _confirmTransfer(
            toUserId: u.id,
            toUserName: u.displayName.isNotEmpty ? u.displayName : u.email,
            toUserPhoto: u.photoUrl,
          ),
          onPlayerTap: _replaceWithPlayer,
        );
    }
  }
}

class _RadioTabBar extends StatelessWidget {
  const _RadioTabBar({
    required this.selected,
    required this.onSelected,
  });

  final _ChangeScorerTab selected;
  final ValueChanged<_ChangeScorerTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RadioTab(
            label: 'QR code',
            selected: selected == _ChangeScorerTab.qrCode,
            onTap: () => onSelected(_ChangeScorerTab.qrCode),
          ),
        ),
        Expanded(
          child: _RadioTab(
            label: 'Teams',
            selected: selected == _ChangeScorerTab.teams,
            onTap: () => onSelected(_ChangeScorerTab.teams),
          ),
        ),
        Expanded(
          child: _RadioTab(
            label: 'Officials',
            selected: selected == _ChangeScorerTab.officials,
            onTap: () => onSelected(_ChangeScorerTab.officials),
          ),
        ),
        Expanded(
          child: _RadioTab(
            label: 'Search',
            selected: selected == _ChangeScorerTab.search,
            onTap: () => onSelected(_ChangeScorerTab.search),
          ),
        ),
      ],
    );
  }
}

class _RadioTab extends StatelessWidget {
  const _RadioTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.primaryBlue : AppColors.border,
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryBlue,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrTab extends StatelessWidget {
  const _QrTab({
    required this.loading,
    required this.payload,
    required this.displayId,
  });

  final bool loading;
  final String? payload;
  final String displayId;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
      child: Column(
        children: [
          const Text(
            'Ask the new scorer to scan below QR code.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Match ID: $displayId',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(),
            )
          else if (payload != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: payload!,
                version: QrVersions.auto,
                size: 220,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: AppColors.accentRed,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: AppColors.accentRed,
                ),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _TeamsTab extends ConsumerWidget {
  const _TeamsTab({
    required this.match,
    required this.teamA,
    required this.currentScorerId,
    required this.onTeamChanged,
    required this.onPlayerTap,
  });

  final MatchModel match;
  final bool teamA;
  final String? currentScorerId;
  final ValueChanged<bool> onTeamChanged;
  final Future<void> Function(PlayerModel) onPlayerTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamId = teamA ? match.teamAId : match.teamBId;
    final teamName = teamA ? match.teamAName : match.teamBName;
    final setup = match.setup;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
          child: Text(
            'Who will score from one of the teams?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
          child: Row(
            children: [
              Expanded(
                child: _TeamPill(
                  label: match.teamAName,
                  selected: teamA,
                  onTap: () => onTeamChanged(true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TeamPill(
                  label: match.teamBName,
                  selected: !teamA,
                  onTap: () => onTeamChanged(false),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _TeamPlayersList(
            teamId: teamId,
            teamName: teamName,
            setup: setup,
            isTeamA: teamA,
            currentScorerId: currentScorerId,
            onPlayerTap: onPlayerTap,
          ),
        ),
      ],
    );
  }
}

class _TeamPill extends StatelessWidget {
  const _TeamPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primaryBlue : AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _TeamPlayersList extends ConsumerWidget {
  const _TeamPlayersList({
    required this.teamId,
    required this.teamName,
    required this.setup,
    required this.isTeamA,
    required this.currentScorerId,
    required this.onPlayerTap,
  });

  final String? teamId;
  final String teamName;
  final MatchSetupData? setup;
  final bool isTeamA;
  final String? currentScorerId;
  final Future<void> Function(PlayerModel) onPlayerTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (teamId == null || teamId!.isEmpty) {
      return const Center(child: Text('No team selected'));
    }

    final squadIds = setup?.squadIdsForTeam(isTeamA) ?? [];
    final squadNames = setup?.squadNamesForTeam(isTeamA) ?? {};

    return FutureBuilder<List<PlayerModel>>(
      future: ref.read(playerRepositoryProvider).getPlayersByTeam(teamId!),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var players = snap.data ?? [];
        if (squadIds.isNotEmpty) {
          players = players.where((p) => squadIds.contains(p.id)).toList();
          final loadedIds = players.map((p) => p.id).toSet();
          for (final id in squadIds) {
            if (!loadedIds.contains(id)) {
              players.add(
                PlayerModel(
                  id: id,
                  name: squadNames[id] ?? 'Player',
                  teamId: teamId,
                ),
              );
            }
          }
        }

        if (players.isEmpty) {
          return Center(
            child: Text(
              'No players in $teamName playing XI',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
          itemCount: players.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final p = players[i];
            final isCurrentScorer =
                currentScorerId != null &&
                p.userId != null &&
                p.userId == currentScorerId;
            return _SelectablePersonTile(
              name: p.name,
              photoUrl: p.photoUrl,
              isCurrentScorer: isCurrentScorer,
              onTap: isCurrentScorer ? null : () => onPlayerTap(p),
            );
          },
        );
      },
    );
  }
}

class _OfficialsTab extends StatelessWidget {
  const _OfficialsTab({
    required this.match,
    required this.currentScorerId,
    required this.onOfficialTap,
    required this.onAddOfficials,
  });

  final MatchModel match;
  final String? currentScorerId;
  final Future<void> Function(MatchOfficialEntry) onOfficialTap;
  final VoidCallback onAddOfficials;

  @override
  Widget build(BuildContext context) {
    final setup = match.setup;
    final officials = <_OfficialRow>[];

    if (setup != null) {
      for (final u in setup.umpires) {
        if (u.name.isNotEmpty) {
          officials.add(_OfficialRow(role: 'Umpire', entry: u));
        }
      }
      for (final s in setup.scorers) {
        if (s.name.isNotEmpty) {
          officials.add(_OfficialRow(role: 'Scorer', entry: s));
        }
      }
      if (setup.referee != null && setup.referee!.name.isNotEmpty) {
        officials.add(_OfficialRow(role: 'Referee', entry: setup.referee!));
      }
      if (match.createdBy != null) {
        final organizerName = match.createdBy == currentScorerId &&
                match.currentScorerName.isNotEmpty
            ? match.currentScorerName
            : 'Match organizer';
        officials.add(
          _OfficialRow(
            role: 'Organizer',
            entry: MatchOfficialEntry(
              playerId: match.createdBy,
              name: organizerName,
            ),
          ),
        );
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
      child: Column(
        children: [
          const Text(
            'Transfer scoring to a match official.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          if (officials.isEmpty)
            TextButton(
              onPressed: onAddOfficials,
              child: const Text(
                'Add match officials',
                style: TextStyle(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            )
          else
            ...officials.map(
              (o) {
                final isCurrentScorer = currentScorerId != null &&
                    o.entry.playerId != null &&
                    o.entry.playerId == currentScorerId;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          o.entry.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (isCurrentScorer) const _CurrentScorerBadge(),
                    ],
                  ),
                  subtitle: Text(
                    o.role,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  trailing: Icon(
                    isCurrentScorer
                        ? Icons.sports_score
                        : Icons.check_circle_outline,
                    color: isCurrentScorer
                        ? AppColors.gold
                        : AppColors.textMuted,
                  ),
                  onTap: isCurrentScorer
                      ? null
                      : () => onOfficialTap(o.entry),
                );
              },
            ),
          if (officials.isNotEmpty) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: onAddOfficials,
              child: const Text(
                'Add match officials',
                style: TextStyle(color: AppColors.primaryBlue),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OfficialRow {
  const _OfficialRow({required this.role, required this.entry});
  final String role;
  final MatchOfficialEntry entry;
}

class _SearchTab extends StatelessWidget {
  const _SearchTab({
    required this.controller,
    required this.searching,
    required this.error,
    required this.results,
    required this.playerResults,
    required this.replaceSlotIndex,
    required this.onReplaceSlotChanged,
    required this.currentScorerId,
    required this.onSearch,
    required this.onUserTap,
    required this.onPlayerTap,
  });

  final TextEditingController controller;
  final bool searching;
  final String? error;
  final List<UserModel> results;
  final List<PlayerModel> playerResults;
  final int replaceSlotIndex;
  final ValueChanged<int> onReplaceSlotChanged;
  final String? currentScorerId;
  final VoidCallback onSearch;
  final Future<void> Function(UserModel) onUserTap;
  final Future<void> Function(PlayerModel) onPlayerTap;

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final combinedPlayers = <PlayerModel>[
      ...playerResults,
      for (final u in results)
        if (!playerResults.any((p) => p.userId == u.id))
          PlayerModel(
            id: u.id,
            name: u.effectiveName,
            userId: u.id,
            playerId: u.playerId,
            photoUrl: u.photoUrl,
          ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
          child: Column(
            children: [
              if (!keyboardOpen) ...[
                const Text(
                  'Search by player name or Player ID to assign a scorer.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Scorer 1')),
                  ButtonSegment(value: 1, label: Text('Scorer 2')),
                ],
                selected: {replaceSlotIndex},
                onSelectionChanged: (s) => onReplaceSlotChanged(s.first),
              ),
            ],
          ),
        ),
        SizedBox(height: keyboardOpen ? 8 : 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  autofocus: false,
                  decoration: InputDecoration(
                    hintText: 'Search by name or Player ID',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => onSearch(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: searching ? null : onSearch,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(88, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: searching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Search'),
              ),
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.accentRed),
            ),
          ),
        Expanded(
          child: combinedPlayers.isEmpty
              ? Center(
                  child: Text(
                    searching ? 'Searching…' : 'Search for a player',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceMd,
                  ),
                  itemCount: combinedPlayers.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final p = combinedPlayers[i];
                    final isCurrentScorer =
                        currentScorerId != null && p.userId == currentScorerId;
                    return _SelectablePersonTile(
                      name: p.name,
                      photoUrl: p.photoUrl,
                      subtitle: CfPlayerIdFormat.displayLabel(p.playerId),
                      isCurrentScorer: isCurrentScorer,
                      onTap: isCurrentScorer ? null : () => onPlayerTap(p),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SelectablePersonTile extends StatelessWidget {
  const _SelectablePersonTile({
    required this.name,
    this.onTap,
    this.photoUrl,
    this.subtitle,
    this.isCurrentScorer = false,
  });

  final String name;
  final String? photoUrl;
  final String? subtitle;
  final bool isCurrentScorer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      enabled: onTap != null,
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.surfaceElevated,
        backgroundImage: photoUrl != null && photoUrl!.isNotEmpty
            ? CachedNetworkImageProvider(photoUrl!)
            : null,
        child: photoUrl == null || photoUrl!.isEmpty
            ? Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(fontWeight: FontWeight.w700),
              )
            : null,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isCurrentScorer
                    ? AppColors.gold
                    : AppColors.textPrimary,
              ),
            ),
          ),
          if (isCurrentScorer) const _CurrentScorerBadge(),
        ],
      ),
      subtitle: subtitle != null && subtitle!.isNotEmpty
          ? Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            )
          : null,
      trailing: Icon(
        isCurrentScorer ? Icons.sports_score : Icons.check_circle_outline,
        color: isCurrentScorer ? AppColors.gold : AppColors.textMuted,
      ),
      onTap: onTap,
    );
  }
}

class _CurrentScorerBadge extends StatelessWidget {
  const _CurrentScorerBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
      ),
      child: const Text(
        'Scoring',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AppColors.gold,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
