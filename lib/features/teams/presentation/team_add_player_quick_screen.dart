import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/cf_player_id_format.dart';
import '../../../data/models/player_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/team_players_provider.dart';
import '../../../shared/widgets/cf_button.dart';
import '../../../shared/widgets/cf_underlined_field.dart';

/// Add a registered player by public ID, or create a walk-in without an account.
class TeamAddPlayerQuickScreen extends ConsumerStatefulWidget {
  const TeamAddPlayerQuickScreen({super.key, required this.teamId});

  final String teamId;

  @override
  ConsumerState<TeamAddPlayerQuickScreen> createState() =>
      _TeamAddPlayerQuickScreenState();
}

class _TeamAddPlayerQuickScreenState
    extends ConsumerState<TeamAddPlayerQuickScreen> {
  final _playerIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _jerseyController = TextEditingController();

  Timer? _debounce;
  PlayerModel? _found;
  Set<String> _squadIds = {};
  var _searching = false;
  var _saving = false;
  var _role = 'Player';
  String? _lookupError;

  @override
  void initState() {
    super.initState();
    _loadSquadIds();
    _playerIdController.addListener(_onPlayerIdChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _playerIdController.dispose();
    _nameController.dispose();
    _jerseyController.dispose();
    super.dispose();
  }

  Future<void> _loadSquadIds() async {
    final squad = await ref
        .read(playerRepositoryProvider)
        .getPlayersByTeam(widget.teamId);
    if (mounted) setState(() => _squadIds = squad.map((p) => p.id).toSet());
  }

  void _onPlayerIdChanged() {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _lookupPlayer);
  }

  Future<void> _lookupPlayer() async {
    final raw = _playerIdController.text.trim();
    if (raw.isEmpty) {
      if (mounted) {
        setState(() {
          _found = null;
          _lookupError = null;
          _searching = false;
        });
      }
      return;
    }

    setState(() {
      _searching = true;
      _lookupError = null;
      _found = null;
    });

    try {
      PlayerModel? player;
      if (CfPlayerIdFormat.looksLikeCfPlayerId(raw)) {
        player = await ref
            .read(playerRepositoryProvider)
            .getPlayerByPublicId(raw);
      } else {
        final results = await ref
            .read(playerRepositoryProvider)
            .searchAvailablePlayers(
              excludeTeamId: widget.teamId,
              alreadyOnSquadIds: _squadIds,
              query: raw,
            );
        if (results.length == 1) {
          player = results.first;
        } else if (results.length > 1 &&
            CfPlayerIdFormat.normalize(raw).length >= 3) {
          player = results.firstWhere(
            (p) =>
                p.playerId?.toUpperCase().startsWith(
                  CfPlayerIdFormat.normalize(raw),
                ) ??
                false,
            orElse: () => results.first,
          );
        }
      }

      if (!mounted) return;
      if (player == null) {
        setState(() {
          _lookupError = CfPlayerIdFormat.looksLikeCfPlayerId(raw)
              ? 'No player found for ${CfPlayerIdFormat.normalize(raw)}'
              : 'Enter a full Player ID (e.g. CF000042)';
        });
        return;
      }

      final resolved = player;
      if (_squadIds.contains(resolved.id) || resolved.isOnTeam(widget.teamId)) {
        setState(
          () => _lookupError = '${resolved.name} is already on this squad',
        );
      } else {
        setState(() => _found = resolved);
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _addFound() async {
    final player = _found;
    if (player == null) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(playerRepositoryProvider)
          .assignPlayerToTeam(playerId: player.id, teamId: widget.teamId);
      ref.invalidate(teamPlayersProvider(widget.teamId));
      if (!mounted) return;
      context.pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${player.name} added to squad')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not add player: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addWalkIn() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Player name is required')));
      return;
    }

    setState(() => _saving = true);
    try {
      final uid = ref.read(authStateProvider).value?.uid;
      final playerId = const Uuid().v4();
      final player = PlayerModel(
        id: playerId,
        name: name,
        teamId: widget.teamId,
        jerseyNumber: int.tryParse(_jerseyController.text.trim()),
        role: _role,
        createdBy: uid,
      );
      await ref.read(playerRepositoryProvider).createPlayer(player);
      await ref
          .read(teamRepositoryProvider)
          .addPlayerToTeam(teamId: widget.teamId, playerId: playerId);
      ref.invalidate(teamPlayersProvider(widget.teamId));
      if (!mounted) return;
      context.pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$name added to squad')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not add player: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add by Player ID')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: AppDimens.listPadding,
              children: [
                Text(
                  'Find a registered player',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter their CrickFlow Player ID. They must have completed onboarding.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppDimens.spaceLg),
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _playerIdController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: 'Player ID',
                          hintText: CfPlayerIdFormat.hint(),
                          prefixIcon: const Icon(Icons.badge_outlined),
                          suffixIcon: _searching
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : _playerIdController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _playerIdController.clear();
                                    setState(() {
                                      _found = null;
                                      _lookupError = null;
                                    });
                                  },
                                )
                              : null,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      if (_lookupError != null) ...[
                        const SizedBox(height: AppDimens.spaceSm),
                        Text(
                          _lookupError!,
                          style: const TextStyle(color: AppColors.accentRed),
                        ),
                      ],
                      if (_found != null) ...[
                        const SizedBox(height: AppDimens.spaceMd),
                        _PlayerPreviewCard(player: _found!),
                        const SizedBox(height: AppDimens.spaceMd),
                        CfButton(
                          label: 'Add to squad',
                          isLoading: _saving,
                          onPressed: _saving ? null : _addFound,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppDimens.spaceLg),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'No CrickFlow account?',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: AppDimens.spaceLg),
                Text(
                  'Add walk-in player',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'For guests who are not on CrickFlow — name only, no login required.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppDimens.spaceMd),
                _sectionCard(
                  child: CfFormFieldGroup(
                    children: [
                      CfUnderlinedField(
                        controller: _nameController,
                        label: 'Player name',
                        required: true,
                      ),
                      CfUnderlinedField(
                        controller: _jerseyController,
                        label: 'Jersey number',
                        keyboardType: TextInputType.number,
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: _role,
                        decoration: const InputDecoration(labelText: 'Role'),
                        items:
                            const [
                                  'Player',
                                  'Captain',
                                  'Wicket Keeper',
                                  'All-rounder',
                                ]
                                .map(
                                  (r) => DropdownMenuItem(
                                    value: r,
                                    child: Text(r),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _role = v);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.spaceMd),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _saving ? null : _addWalkIn,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.black,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add walk-in to squad'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Card(
      elevation: 0,
      color: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: child,
      ),
    );
  }
}

class _PlayerPreviewCard extends StatelessWidget {
  const _PlayerPreviewCard({required this.player});

  final PlayerModel player;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundImage: player.photoUrl != null
                ? CachedNetworkImageProvider(player.photoUrl!)
                : null,
            child: player.photoUrl == null
                ? Text(
                    player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 20),
                  )
                : null,
          ),
          const SizedBox(width: AppDimens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (player.playerId != null && player.playerId!.isNotEmpty)
                  Text(
                    CfPlayerIdFormat.displayLabel(player.playerId),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.gold),
                  ),
                Text(
                  player.role,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle_outline, color: AppColors.gold),
        ],
      ),
    );
  }
}
