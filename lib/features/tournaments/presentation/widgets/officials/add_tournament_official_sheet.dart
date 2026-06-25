import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/enums.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/cf_colors.dart';
import '../../../../../data/models/player_model.dart';
import '../../../../../data/models/tournament_model.dart';
import '../../../../../shared/providers/providers.dart';
import '../../../../../shared/providers/tournament_providers.dart';
import '../../../../../shared/widgets/cf_button.dart';
import '../../utils/tournament_display_utils.dart';

Future<void> showAddTournamentOfficialSheet({
  required BuildContext context,
  required WidgetRef ref,
  required TournamentModel tournament,
  TournamentOfficialRole initialRole = TournamentOfficialRole.umpire,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    builder: (_) => AddTournamentOfficialSheet(
      tournament: tournament,
      parentRef: ref,
      initialRole: initialRole,
    ),
  );
}

class AddTournamentOfficialSheet extends ConsumerStatefulWidget {
  const AddTournamentOfficialSheet({
    super.key,
    required this.tournament,
    required this.parentRef,
    required this.initialRole,
  });

  final TournamentModel tournament;
  final WidgetRef parentRef;
  final TournamentOfficialRole initialRole;

  @override
  ConsumerState<AddTournamentOfficialSheet> createState() =>
      _AddTournamentOfficialSheetState();
}

class _AddTournamentOfficialSheetState
    extends ConsumerState<AddTournamentOfficialSheet> {
  late TournamentOfficialRole _role;
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<PlayerModel> _results = [];
  PlayerModel? _selected;
  bool _searching = false;
  bool _saving = false;

  static const _roles = TournamentOfficialRole.values;

  @override
  void initState() {
    super.initState();
    _role = widget.initialRole;
    _search('');
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
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
          .searchPlayersDirectory(query: query);
      if (mounted) setState(() => _results = results);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _addSelf() async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    final player =
        await ref.read(playerRepositoryProvider).getPlayerByUserId(uid);
    await _submit(
      userId: uid,
      displayName: profile?.displayName ?? profile?.name ?? player?.name ?? 'Official',
      playerId: player?.playerId ?? player?.id ?? '',
      photoUrl: profile?.photoUrl ?? player?.photoUrl,
    );
  }

  Future<void> _submit({
    required String userId,
    required String displayName,
    String playerId = '',
    String? photoUrl,
  }) async {
    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a player with a linked account')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final uid = ref.read(authStateProvider).value?.uid ?? '';
      final profile = ref.read(currentUserProfileProvider).valueOrNull;
      await ref.read(tournamentOfficialInviteServiceProvider).inviteOfficial(
            tournament: widget.tournament,
            organizerId: uid,
            organizerName: profile?.displayName ?? 'Organizer',
            targetUserId: userId,
            role: _role,
            displayName: displayName,
            playerId: playerId,
            photoUrl: photoUrl,
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userId == uid
                ? 'You were added as ${tournamentOfficialRoleSingular(_role)}'
                : 'Invitation sent to $displayName',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final uid = ref.watch(authStateProvider).value?.uid;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Material(
            color: cf.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: AppDimens.screenPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: cf.border,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      Text(
                        'Add official',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Search by name or Player ID. Invites are sent except when you add yourself.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cf.textSecondary,
                            ),
                      ),
                      const SizedBox(height: AppDimens.spaceMd),
                      Text(
                        'Role',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: AppDimens.spaceSm),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _roles.map((role) {
                          return ChoiceChip(
                            label: Text(tournamentOfficialRoleSingular(role)),
                            selected: _role == role,
                            onSelected: (_) => setState(() => _role = role),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: AppDimens.spaceMd),
                      TextField(
                        controller: _searchController,
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
                          filled: true,
                          fillColor: cf.sectionBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      if (uid != null) ...[
                        const SizedBox(height: AppDimens.spaceSm),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _saving ? null : _addSelf,
                            icon: const Icon(Icons.person_add_alt_1_outlined),
                            label: Text(
                              'Add myself as ${tournamentOfficialRoleSingular(_role)}',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spaceMd,
                    ),
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: cf.border),
                    itemBuilder: (_, i) {
                      final player = _results[i];
                      final selected = _selected?.id == player.id;
                      return _PlayerPickTile(
                        player: player,
                        selected: selected,
                        onTap: () => setState(() => _selected = player),
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: AppDimens.screenPadding,
                    child: CfButton(
                      label: _saving ? 'Adding…' : 'Send invitation',
                      isGold: true,
                      onPressed: _saving || _selected == null
                          ? null
                          : () {
                              final p = _selected!;
                              final authUid =
                                  (p.userId != null && p.userId!.isNotEmpty)
                                      ? p.userId!
                                      : p.id;
                              if (authUid.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'This player has no linked account for notifications',
                                    ),
                                  ),
                                );
                                return;
                              }
                              _submit(
                                userId: authUid,
                                displayName: p.name,
                                playerId: p.playerId ?? p.id,
                                photoUrl: p.photoUrl,
                              );
                            },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PlayerPickTile extends StatelessWidget {
  const _PlayerPickTile({
    required this.player,
    required this.selected,
    required this.onTap,
  });

  final PlayerModel player;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final idLabel = player.playerId?.isNotEmpty == true ? player.playerId : null;

    return Material(
      color: selected ? cf.accent.withValues(alpha: 0.08) : Colors.transparent,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: cf.sectionBackground,
          backgroundImage: player.photoUrl != null
              ? CachedNetworkImageProvider(player.photoUrl!)
              : null,
          child: player.photoUrl == null
              ? Text(player.name.isNotEmpty ? player.name[0].toUpperCase() : '?')
              : null,
        ),
        title: Text(player.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: idLabel != null
            ? Text(idLabel!, style: TextStyle(color: cf.accent, fontSize: 12))
            : null,
        trailing: selected
            ? Icon(Icons.check_circle, color: cf.accent)
            : Icon(Icons.circle_outlined, color: cf.textMuted),
      ),
    );
  }
}
