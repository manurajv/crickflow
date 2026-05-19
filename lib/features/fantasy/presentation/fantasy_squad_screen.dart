import 'package:flutter/material.dart';
import 'package:crickflow/core/theme/app_dimens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/fantasy_entry_model.dart';
import '../../../data/models/fantasy_league_model.dart';
import '../../../data/models/player_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/team_players_provider.dart';
import '../../../shared/widgets/cf_button.dart';

class FantasySquadScreen extends ConsumerStatefulWidget {
  const FantasySquadScreen({super.key, required this.leagueId});

  final String leagueId;

  @override
  ConsumerState<FantasySquadScreen> createState() => _FantasySquadScreenState();
}

class _FantasySquadScreenState extends ConsumerState<FantasySquadScreen> {
  final Set<String> _selected = {};
  String? _captainId;
  String? _viceCaptainId;
  bool _saving = false;
  bool _loadedFromEntry = false;

  @override
  Widget build(BuildContext context) {
    final leagueAsync = ref.watch(fantasyLeagueProvider(widget.leagueId));
    final uid = ref.watch(authStateProvider).value?.uid;

    return leagueAsync.when(
      data: (league) {
        if (league == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('League not found')),
          );
        }

        final matchAsync = ref.watch(matchProvider(league.matchId));
        final myEntryAsync = uid == null
            ? const AsyncValue.data(null)
            : ref.watch(fantasyMyEntryProvider((widget.leagueId, uid)));

        return matchAsync.when(
          data: (match) {
            if (match == null) {
              return Scaffold(
                appBar: AppBar(title: const Text('Build squad')),
                body: const Center(child: Text('Match not found')),
              );
            }

            final teamIds = [
              if (match.teamAId != null && match.teamAId!.isNotEmpty)
                match.teamAId!,
              if (match.teamBId != null && match.teamBId!.isNotEmpty)
                match.teamBId!,
            ];

            return Scaffold(
              appBar: AppBar(
                title: Text(
                  'Build squad (${_selected.length}/${league.squadSize})',
                ),
              ),
              body: myEntryAsync.when(
                data: (entry) {
                  if (entry == null) {
                    return const Center(
                      child: Text('Join the league first from the league screen.'),
                    );
                  }

                  if (!_loadedFromEntry) {
                    _loadedFromEntry = true;
                    _selected.addAll(entry.playerIds);
                    _captainId = entry.captainId;
                    _viceCaptainId = entry.viceCaptainId;
                  }

                  if (teamIds.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppDimens.spaceLg),
                        child: Text(
                          'Link teams to this match before picking a fantasy squad.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.only(bottom: 100),
                          children: [
                            for (final teamId in teamIds)
                              _TeamPlayerSection(
                                teamId: teamId,
                                label: teamId == match.teamAId
                                    ? match.teamAName
                                    : match.teamBName,
                                selected: _selected,
                                captainId: _captainId,
                                viceCaptainId: _viceCaptainId,
                                squadSize: league.squadSize,
                                onToggle: _togglePlayer,
                                onCaptain: (id) =>
                                    setState(() => _captainId = id),
                                onVice: (id) =>
                                    setState(() => _viceCaptainId = id),
                              ),
                          ],
                        ),
                      ),
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(AppDimens.spaceMd),
                          child: CfButton(
                            label: _saving ? 'Saving…' : 'Save squad',
                            icon: Icons.check,
                            onPressed: _saving ||
                                    _selected.length != league.squadSize ||
                                    _captainId == null ||
                                    _viceCaptainId == null
                                ? null
                                : () => _save(context, league, entry),
                          ),
                        ),
                      ),
                    ],
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
              ),
            );
          },
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
    );
  }

  void _togglePlayer(String playerId) {
    setState(() {
      if (_selected.contains(playerId)) {
        _selected.remove(playerId);
        if (_captainId == playerId) _captainId = null;
        if (_viceCaptainId == playerId) _viceCaptainId = null;
      } else {
        final league = ref.read(fantasyLeagueProvider(widget.leagueId)).value;
        final max = league?.squadSize ?? 11;
        if (_selected.length >= max) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('You can only pick $max players')),
          );
          return;
        }
        _selected.add(playerId);
      }
    });
  }

  Future<void> _save(
    BuildContext context,
    FantasyLeagueModel league,
    FantasyEntryModel entry,
  ) async {
    setState(() => _saving = true);
    try {
      final events = await ref
          .read(matchRepositoryProvider)
          .getBallEvents(league.matchId);
      await ref.read(fantasyRepositoryProvider).saveSquad(
            league: league,
            entry: entry,
            playerIds: _selected.toList(),
            captainId: _captainId!,
            viceCaptainId: _viceCaptainId!,
            ballEvents: events,
          );
      if (!context.mounted) return;
      context.pop();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _TeamPlayerSection extends ConsumerWidget {
  const _TeamPlayerSection({
    required this.teamId,
    required this.label,
    required this.selected,
    required this.captainId,
    required this.viceCaptainId,
    required this.squadSize,
    required this.onToggle,
    required this.onCaptain,
    required this.onVice,
  });

  final String teamId;
  final String label;
  final Set<String> selected;
  final String? captainId;
  final String? viceCaptainId;
  final int squadSize;
  final void Function(String id) onToggle;
  final void Function(String id) onCaptain;
  final void Function(String id) onVice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playersAsync = ref.watch(teamPlayersProvider(teamId));

    return playersAsync.when(
      data: (players) {
        if (players.isEmpty) {
          return ListTile(
            title: Text(label),
            subtitle: const Text('No players on roster'),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppDimens.spaceMd, AppDimens.spaceMd, AppDimens.spaceMd, AppDimens.spaceSm),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...players.map((p) => _playerTile(context, p)),
          ],
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('$e'),
    );
  }

  Widget _playerTile(BuildContext context, PlayerModel player) {
    final isSelected = selected.contains(player.id);
    final isCaptain = captainId == player.id;
    final isVice = viceCaptainId == player.id;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          CheckboxListTile(
            value: isSelected,
            onChanged: (_) => onToggle(player.id),
            title: Text(player.name),
            subtitle: player.role.isNotEmpty ? Text(player.role) : null,
            secondary: isCaptain
                ? const Chip(
                    label: Text('C'),
                    visualDensity: VisualDensity.compact,
                  )
                : isVice
                    ? const Chip(
                        label: Text('VC'),
                        visualDensity: VisualDensity.compact,
                      )
                    : null,
          ),
          if (isSelected)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Captain (2×)'),
                    selected: isCaptain,
                    onSelected: (_) => onCaptain(player.id),
                    selectedColor: AppColors.gold.withValues(alpha: 0.3),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Vice (1.5×)'),
                    selected: isVice,
                    onSelected: (_) => onVice(player.id),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
