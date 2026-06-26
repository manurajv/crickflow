import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/player_profile_constants.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/cf_player_id_format.dart';
import '../../../../data/models/match_player_snapshot.dart';
import '../../../../data/models/player_model.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/cf_underlined_field.dart';
import '../../../../core/theme/cf_colors.dart';

/// Bottom sheet: permanently add a team player or create a match-only guest.
Future<MatchPlayerSnapshot?> showAddMatchSquadPlayerSheet(
  BuildContext context, {
  required String teamId,
}) {
  return showModalBottomSheet<MatchPlayerSnapshot>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.cf.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _AddMatchSquadPlayerSheet(teamId: teamId),
  );
}

class _AddMatchSquadPlayerSheet extends ConsumerStatefulWidget {
  const _AddMatchSquadPlayerSheet({required this.teamId});

  final String teamId;

  @override
  ConsumerState<_AddMatchSquadPlayerSheet> createState() =>
      _AddMatchSquadPlayerSheetState();
}

class _AddMatchSquadPlayerSheetState
    extends ConsumerState<_AddMatchSquadPlayerSheet> {
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();

  Timer? _debounce;
  List<PlayerModel> _results = [];
  Set<String> _squadIds = {};
  var _searching = false;
  String? _addingPlayerId;
  var _mode = _AddMode.choose;
  PlayerPlayingRole? _role;
  String? _battingStyle;
  PlayerBowlingStyle? _bowlingStyle;

  static final _guestRoles = [
    PlayerPlayingRole.batsman,
    PlayerPlayingRole.bowler,
    PlayerPlayingRole.allRounder,
    PlayerPlayingRole.wicketKeeper,
    PlayerPlayingRole.wicketKeeperBatter,
  ];

  static const _guestBattingStyles = [
    'Right Hand Bat',
    'Left Hand Bat',
  ];

  static final _guestBowlingStyles = [
    PlayerBowlingStyle.rightArmFast,
    PlayerBowlingStyle.leftArmFast,
    PlayerBowlingStyle.rightArmMedium,
    PlayerBowlingStyle.leftArmMedium,
    PlayerBowlingStyle.rightArmOffSpin,
    PlayerBowlingStyle.rightArmLegSpin,
    PlayerBowlingStyle.leftArmOrthodoxSpin,
    PlayerBowlingStyle.leftArmChinaman,
  ];

  @override
  void initState() {
    super.initState();
    _loadSquadIds();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSquadIds() async {
    final squad = await ref
        .read(playerRepositoryProvider)
        .getPlayersByTeam(widget.teamId);
    if (mounted) setState(() => _squadIds = squad.map((p) => p.id).toSet());
  }

  void _onSearchChanged() {
    if (_mode != _AddMode.permanent) return;
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _search(_searchController.text);
    });
  }

  Future<void> _search(String query) async {
    setState(() => _searching = true);
    try {
      final results = await ref
          .read(playerRepositoryProvider)
          .searchAvailablePlayers(
            excludeTeamId: widget.teamId,
            alreadyOnSquadIds: _squadIds,
            query: query,
          );
      if (mounted) setState(() => _results = results);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _openPermanentMode() {
    setState(() => _mode = _AddMode.permanent);
    _searchController.clear();
    _results = [];
    _search('');
  }

  Future<void> _invitePermanent(PlayerModel player) async {
    setState(() => _addingPlayerId = player.id);
    try {
      final uid = ref.read(authStateProvider).value?.uid;
      if (uid == null) return;

      final team = await ref.read(teamRepositoryProvider).getTeam(widget.teamId);
      if (team == null) {
        _showError('Team not found');
        return;
      }

      final profile = ref.read(currentUserProfileProvider).valueOrNull;
      await ref.read(teamJoinRequestRepositoryProvider).createInvitation(
            team: team,
            player: player,
            invitedByUserId: uid,
            inviterName: profile?.displayName ?? profile?.name,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invitation sent to ${player.name}')),
      );
    } catch (e) {
      if (mounted) {
        _showError('Could not send invitation: $e');
      }
    } finally {
      if (mounted) setState(() => _addingPlayerId = null);
    }
  }

  void _saveGuest() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Full name is required');
      return;
    }
    if (_role == null) {
      _showError('Playing role is required');
      return;
    }
    if (_battingStyle == null) {
      _showError('Batting style is required');
      return;
    }
    if (_bowlingStyle == null) {
      _showError('Bowling style is required');
      return;
    }

    Navigator.of(context).pop(
      MatchPlayerSnapshot.matchOnly(
        name: name,
        playingRole: _role!.label,
        battingStyle: _battingStyle!,
        bowlingStyle: _bowlingStyle!.label,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: switch (_mode) {
          _AddMode.choose => _buildChoose(),
          _AddMode.permanent => _buildPermanentSearch(),
          _AddMode.guest => _buildGuestForm(),
        },
      ),
    );
  }

  Widget _buildChoose() {
    final cf = context.cf;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        0,
        AppDimens.spaceMd,
        AppDimens.spaceLg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Add player',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            'Add a permanent team member or a match-only guest for this match.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cf.textSecondary,
                ),
          ),
          const SizedBox(height: AppDimens.spaceLg),
          _OptionCard(
            icon: Icons.group_add_outlined,
            iconColor: cf.link,
            iconBackground: cf.accent.withValues(alpha: 0.2),
            title: 'Invite to team',
            subtitle:
                'Search by name or Player ID and send an invitation to join the roster.',
            onTap: _openPermanentMode,
          ),
          const SizedBox(height: AppDimens.spaceSm),
          _OptionCard(
            icon: Icons.person_outline,
            iconColor: Colors.orange.shade800,
            iconBackground: Colors.orange.withValues(alpha: 0.15),
            title: 'Add match-only guest',
            subtitle: 'Guest players exist only for this match — not saved to the team.',
            onTap: () => setState(() => _mode = _AddMode.guest),
          ),
        ],
      ),
    );
  }

  Widget _buildPermanentSearch() {
    final cf = context.cf;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.spaceMd,
            0,
            AppDimens.spaceMd,
            AppDimens.spaceSm,
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _mode = _AddMode.choose),
                icon: const Icon(Icons.arrow_back),
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Text(
                  'Invite to team',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
          child: Text(
            'Search by name or Player ID. The player must accept before joining the team.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cf.textSecondary,
                ),
          ),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Search by name or Player ID',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _searchController.clear,
                        )
                      : null,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.spaceMd,
            AppDimens.spaceSm,
            AppDimens.spaceMd,
            AppDimens.spaceSm,
          ),
          child: Text(
            _results.isEmpty && !_searching
                ? 'No matches — try another name or ID.'
                : '${_results.length} player${_results.length == 1 ? '' : 's'} available',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cf.textSecondary,
                ),
          ),
        ),
        Expanded(
          child: _results.isEmpty && !_searching
              ? _buildEmptySearch()
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: AppDimens.spaceLg),
                  itemCount: _results.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 72),
                  itemBuilder: (_, i) {
                    final player = _results[i];
                    return _PermanentPlayerTile(
                      player: player,
                      isAdding: _addingPlayerId == player.id,
                      onAdd: () => _invitePermanent(player),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptySearch() {
    final cf = context.cf;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search_outlined,
              size: 48,
              color: cf.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Text(
              _searchController.text.trim().isEmpty
                  ? 'Start typing a name or Player ID'
                  : 'No players match your search',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestForm() {
    final cf = context.cf;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        0,
        AppDimens.spaceMd,
        AppDimens.spaceLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _mode = _AddMode.choose),
                icon: const Icon(Icons.arrow_back),
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Text(
                  'Match-only guest',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          Text(
            'Guest players exist only for this match and are not added to the team roster.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cf.textSecondary,
                ),
          ),
          const SizedBox(height: AppDimens.spaceLg),
          Card(
            elevation: 0,
            color: cf.sectionBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: cf.border.withValues(alpha: 0.5)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CfUnderlinedField(
                    controller: _nameController,
                    label: 'Full name',
                    required: true,
                  ),
                  const SizedBox(height: AppDimens.spaceMd),
                  _dropdownLabel('Playing role'),
                  DropdownButtonFormField<PlayerPlayingRole>(
                    value: _role,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    hint: const Text('Select role'),
                    items: _guestRoles
                        .map(
                          (r) => DropdownMenuItem(value: r, child: Text(r.label)),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _role = v),
                  ),
                  const SizedBox(height: AppDimens.spaceMd),
                  _dropdownLabel('Batting style'),
                  DropdownButtonFormField<String>(
                    value: _battingStyle,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    hint: const Text('Select batting style'),
                    items: _guestBattingStyles
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setState(() => _battingStyle = v),
                  ),
                  const SizedBox(height: AppDimens.spaceMd),
                  _dropdownLabel('Bowling style'),
                  DropdownButtonFormField<PlayerBowlingStyle>(
                    value: _bowlingStyle,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    hint: const Text('Select bowling style'),
                    items: _guestBowlingStyles
                        .map(
                          (s) => DropdownMenuItem(value: s, child: Text(s.label)),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _bowlingStyle = v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceLg),
          CfButton(
            label: 'Add guest player',
            onPressed: _saveGuest,
          ),
        ],
      ),
    );
  }

  Widget _dropdownLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cf.sectionBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cf.border.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: iconBackground,
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cf.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cf.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermanentPlayerTile extends StatelessWidget {
  const _PermanentPlayerTile({
    required this.player,
    required this.onAdd,
    this.isAdding = false,
  });

  final PlayerModel player;
  final VoidCallback onAdd;
  final bool isAdding;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final idLabel = player.playerId != null && player.playerId!.isNotEmpty
        ? CfPlayerIdFormat.displayLabel(player.playerId)
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceSm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: cf.sectionBackground,
            backgroundImage: player.photoUrl != null
                ? CachedNetworkImageProvider(player.photoUrl!)
                : null,
            child: player.photoUrl == null
                ? Text(
                    player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: cf.textPrimary,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: cf.textPrimary,
                  ),
                ),
                if (idLabel != null)
                  Text(
                    idLabel,
                    style: TextStyle(
                      color: cf.accent,
                      fontSize: 12,
                      letterSpacing: 0.3,
                    ),
                  ),
                Text(
                  player.role,
                  style: TextStyle(color: cf.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isAdding)
            SizedBox(
              width: 36,
              height: 36,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cf.accent,
                ),
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: Icon(Icons.add, size: 16, color: cf.onAccent),
              label: Text(
                'Invite',
                style: TextStyle(
                  color: cf.onAccent,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: cf.accent,
                foregroundColor: cf.onAccent,
                side: BorderSide(color: cf.accent),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }
}

enum _AddMode { choose, permanent, guest }
