import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../data/models/match_setup_draft_models.dart';
import '../../../data/models/player_model.dart';
import '../../../shared/providers/providers.dart';

/// Pick a registered player as a match official (name + Player ID search).
class AddMatchOfficialScreen extends ConsumerStatefulWidget {
  const AddMatchOfficialScreen({
    super.key,
    required this.title,
    required this.slotLabel,
    this.initial,
  });

  final String title;
  final String slotLabel;
  final MatchOfficialEntry? initial;

  @override
  ConsumerState<AddMatchOfficialScreen> createState() =>
      _AddMatchOfficialScreenState();
}

class _AddMatchOfficialScreenState extends ConsumerState<AddMatchOfficialScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<PlayerModel> _results = [];
  PlayerModel? _selected;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
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
          .searchPlayersDirectory(query: query);
      if (mounted) setState(() => _results = results);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _select(PlayerModel player) {
    setState(() => _selected = player);
  }

  void _confirm() {
    final player = _selected;
    if (player == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a player')),
      );
      return;
    }
    Navigator.pop(
      context,
      MatchOfficialEntry(
        playerId: player.playerId ?? player.id,
        userId: player.userId,
        name: player.name,
        photoUrl: player.photoUrl,
        slotLabel: widget.slotLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              AppDimens.spaceMd,
              AppDimens.spaceMd,
              AppDimens.spaceSm,
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or Player ID (CF000042)',
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
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
            child: Text(
              _results.isEmpty && !_searching
                  ? 'No matches — try another name or Player ID.'
                  : '${_results.length} player${_results.length == 1 ? '' : 's'} found',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Expanded(
            child: _results.isEmpty && !_searching
                ? _emptyState()
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: AppDimens.spaceLg),
                    itemCount: _results.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 72),
                    itemBuilder: (_, i) {
                      final player = _results[i];
                      final selected = _selected?.id == player.id;
                      return _PlayerPickTile(
                        player: player,
                        selected: selected,
                        onTap: () => _select(player),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          child: FilledButton(
            onPressed: _selected != null ? _confirm : null,
            style: FilledButton.styleFrom(
              minimumSize:
                  const Size(double.infinity, AppDimens.buttonHeightLarge),
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
            ),
            child: const Text('Done'),
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search_outlined,
              size: 56,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
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
    final idLabel = player.playerId != null && player.playerId!.isNotEmpty
        ? player.playerId
        : null;

    return Material(
      color: selected
          ? AppColors.gold.withValues(alpha: 0.08)
          : Colors.transparent,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceXs,
        ),
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: AppColors.surfaceElevated,
          backgroundImage: player.photoUrl != null
              ? CachedNetworkImageProvider(player.photoUrl!)
              : null,
          child: player.photoUrl == null
              ? Text(
                  player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                )
              : null,
        ),
        title: Text(
          player.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: idLabel != null
            ? Text(
                idLabel,
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 12,
                  letterSpacing: 0.3,
                ),
              )
            : null,
        trailing: selected
            ? const Icon(Icons.check_circle, color: AppColors.gold)
            : const Icon(Icons.circle_outlined, color: AppColors.textMuted),
      ),
    );
  }
}
