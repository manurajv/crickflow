import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../data/models/match_setup_draft_models.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/start_match_draft_provider.dart';
import '../../../shared/widgets/scoring_ui_kit.dart';
import '../../../shared/widgets/start_match_ui.dart';

/// Assign umpires, scorers, commentators, referee, and streamers.
class MatchOfficialsScreen extends ConsumerStatefulWidget {
  const MatchOfficialsScreen({super.key, this.continueWizard = false});

  /// When true, Done advances to toss (wizard step after roles). Otherwise pops back.
  final bool continueWizard;

  @override
  ConsumerState<MatchOfficialsScreen> createState() =>
      _MatchOfficialsScreenState();
}

class _MatchOfficialsScreenState extends ConsumerState<MatchOfficialsScreen> {
  static const _umpireSlots = [
    'Umpire 1',
    'Umpire 2',
    'Third Umpire',
    '4th Umpire',
  ];
  static const _scorerSlots = ['Scorer 1', 'Scorer 2'];
  static const _commentatorSlots = ['Commentator 1', 'Commentator 2'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureDefaultScorer1());
  }

  Future<void> _ensureDefaultScorer1() async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    final player =
        await ref.read(playerRepositoryProvider).getPlayerByUserId(uid);
    await ref.read(startMatchDraftProvider.notifier).ensureDefaultScorer1(
          userId: uid,
          name: profile?.displayName ?? profile?.name ?? player?.name ?? 'Scorer',
          photoUrl: profile?.photoUrl ?? player?.photoUrl,
          playerId: player?.playerId,
          playerDocId: player?.id,
        );
  }

  void _onDone() {
    if (widget.continueWizard) {
      context.push('/match/create/toss');
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final draft = ref.watch(startMatchDraftProvider);
    final setup = draft.setup;

    return Scaffold(
      backgroundColor: cf.background,
      appBar: AppBar(title: const Text('Match officials')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const StartMatchFlowProgress(
            currentIndex: StartMatchFlowStep.officials,
          ),
          Expanded(
            child: ListView(
              padding: AppDimens.listPadding,
              children: [
          _OfficialSection(
            title: 'Select umpires',
            slots: _umpireSlots,
            entries: setup.umpires,
            icon: Icons.sports,
            onSlotTap: (i) => _openAdd(
              context,
              title: 'Add ${_umpireSlots[i]}',
              slotLabel: _umpireSlots[i],
              type: _OfficialType.umpire,
              index: i,
              entries: setup.umpires,
            ),
            onRemove: (i) => _removeAt(ref, _OfficialType.umpire, i, setup),
          ),
          const SizedBox(height: AppDimens.spaceLg),
          _OfficialSection(
            title: 'Select scorers',
            slots: _scorerSlots,
            entries: setup.scorers,
            icon: Icons.fact_check_outlined,
            lockedSlots: const {0},
            onSlotTap: (i) {
              if (i == 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Scorer 1 is auto-assigned to you as match creator',
                    ),
                  ),
                );
                return;
              }
              _openAdd(
                context,
                title: 'Add Scorer 2',
                slotLabel: 'Scorer 2',
                type: _OfficialType.scorer,
                index: i,
                entries: setup.scorers,
              );
            },
            onRemove: (i) {
              if (i == 0) return;
              _removeAt(ref, _OfficialType.scorer, i, setup);
            },
          ),
          const SizedBox(height: AppDimens.spaceLg),
          _OfficialSection(
            title: 'Select commentators',
            slots: _commentatorSlots,
            entries: setup.commentators,
            icon: Icons.headset_mic_outlined,
            onSlotTap: (i) => _openAdd(
              context,
              title: 'Add ${_commentatorSlots[i]}',
              slotLabel: _commentatorSlots[i],
              type: _OfficialType.commentator,
              index: i,
              entries: setup.commentators,
            ),
            onRemove: (i) =>
                _removeAt(ref, _OfficialType.commentator, i, setup),
          ),
          const SizedBox(height: AppDimens.spaceLg),
          const Text(
            'Others',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Row(
            children: [
              Expanded(
                child: _OtherOfficialCard(
                  label: 'Match referee',
                  entry: setup.referee,
                  icon: Icons.gavel_outlined,
                  onTap: () async {
                    final entry = await context.push<MatchOfficialEntry>(
                      '/match/create/officials/add',
                      extra: {
                        'title': 'Add match referee',
                        'slotLabel': 'Match Referee',
                        'initial': setup.referee,
                      },
                    );
                    if (entry != null) {
                      ref.read(startMatchDraftProvider.notifier).updateOfficials(
                            setup.copyWith(referee: entry),
                          );
                    }
                  },
                  onRemove: setup.referee != null
                      ? () {
                          ref
                              .read(startMatchDraftProvider.notifier)
                              .updateOfficials(
                                setup.copyWith(clearReferee: true),
                              );
                        }
                      : null,
                ),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Expanded(
                child: _OtherOfficialCard(
                  label: 'Live streamer',
                  entry: setup.liveStreamers.isNotEmpty
                      ? setup.liveStreamers.first
                      : null,
                  icon: Icons.live_tv_outlined,
                  onTap: () => _openAdd(
                    context,
                    title: 'Add live streamer',
                    slotLabel: 'Live streamer',
                    type: _OfficialType.streamer,
                    index: 0,
                    entries: setup.liveStreamers,
                  ),
                  onRemove: setup.liveStreamers.isNotEmpty
                      ? () => _removeAt(ref, _OfficialType.streamer, 0, setup)
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          child: FilledButton(
            onPressed: _onDone,
            style: ScoringUiKit.primaryButtonStyle(context).copyWith(
              minimumSize: WidgetStateProperty.all(
                const Size(double.infinity, AppDimens.buttonHeightLarge),
              ),
            ),
            child: const Text('Done'),
          ),
        ),
      ),
    );
  }

  Future<void> _openAdd(
    BuildContext context, {
    required String title,
    required String slotLabel,
    required _OfficialType type,
    required int index,
    required List<MatchOfficialEntry> entries,
  }) async {
    final initial = index < entries.length ? entries[index] : null;
    final entry = await context.push<MatchOfficialEntry>(
      '/match/create/officials/add',
      extra: {
        'title': title,
        'slotLabel': slotLabel,
        'initial': initial,
      },
    );
    if (entry == null) return;
    final setup = ref.read(startMatchDraftProvider).setup;
    final updated = _setAt(
      _listFor(setup, type),
      index,
      entry.copyWith(slotLabel: slotLabel),
    );
    ref.read(startMatchDraftProvider.notifier).updateOfficials(
          _applyList(setup, type, updated),
        );
  }

  void _removeAt(
    WidgetRef ref,
    _OfficialType type,
    int index,
    MatchSetupData setup,
  ) {
    final list = List<MatchOfficialEntry>.from(_listFor(setup, type));
    if (index < list.length) list.removeAt(index);
    ref.read(startMatchDraftProvider.notifier).updateOfficials(
          _applyList(setup, type, list),
        );
  }

  List<MatchOfficialEntry> _listFor(MatchSetupData setup, _OfficialType type) =>
      switch (type) {
        _OfficialType.umpire => setup.umpires,
        _OfficialType.scorer => setup.scorers,
        _OfficialType.commentator => setup.commentators,
        _OfficialType.streamer => setup.liveStreamers,
      };

  MatchSetupData _applyList(
    MatchSetupData setup,
    _OfficialType type,
    List<MatchOfficialEntry> list,
  ) =>
      switch (type) {
        _OfficialType.umpire => setup.copyWith(umpires: list),
        _OfficialType.scorer => setup.copyWith(scorers: list),
        _OfficialType.commentator => setup.copyWith(commentators: list),
        _OfficialType.streamer => setup.copyWith(liveStreamers: list),
      };

  List<MatchOfficialEntry> _setAt(
    List<MatchOfficialEntry> list,
    int index,
    MatchOfficialEntry entry,
  ) {
    final copy = List<MatchOfficialEntry>.from(list);
    while (copy.length <= index) {
      copy.add(MatchOfficialEntry(name: '', slotLabel: ''));
    }
    copy[index] = entry;
    return copy.where((e) => e.name.isNotEmpty).toList();
  }
}

enum _OfficialType { umpire, scorer, commentator, streamer }

class _OfficialSection extends StatelessWidget {
  const _OfficialSection({
    required this.title,
    required this.slots,
    required this.entries,
    required this.icon,
    required this.onSlotTap,
    required this.onRemove,
    this.lockedSlots = const {},
  });

  final String title;
  final List<String> slots;
  final List<MatchOfficialEntry> entries;
  final IconData icon;
  final ValueChanged<int> onSlotTap;
  final ValueChanged<int> onRemove;
  final Set<int> lockedSlots;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: slots.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppDimens.spaceSm),
            itemBuilder: (_, i) {
              final filled = i < entries.length && entries[i].name.isNotEmpty;
              return _OfficialSlotCard(
                slotLabel: slots[i],
                icon: icon,
                entry: filled ? entries[i] : null,
                locked: lockedSlots.contains(i),
                onTap: () => onSlotTap(i),
                onRemove: filled && !lockedSlots.contains(i)
                    ? () => onRemove(i)
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _OfficialSlotCard extends StatelessWidget {
  const _OfficialSlotCard({
    required this.slotLabel,
    required this.icon,
    required this.entry,
    required this.onTap,
    this.onRemove,
    this.locked = false,
  });

  final String slotLabel;
  final IconData icon;
  final MatchOfficialEntry? entry;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final filled = entry != null && entry!.name.isNotEmpty;
    final idLabel = filled && entry!.playerId != null && entry!.playerId!.isNotEmpty
        ? entry!.playerId
        : null;

    return SizedBox(
      width: 108,
      child: Material(
        color: cf.card,
        borderRadius: AppDimens.cardRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppDimens.cardRadius,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: AppDimens.cardRadius,
              border: Border.all(
                color: filled ? cf.accent.withValues(alpha: 0.5) : cf.border,
              ),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: cf.sectionBackground,
                      backgroundImage: filled && entry!.photoUrl != null
                          ? CachedNetworkImageProvider(entry!.photoUrl!)
                          : null,
                      child: filled && entry!.photoUrl == null
                          ? Text(
                              entry!.name[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : !filled
                              ? Icon(icon, color: cf.textSecondary)
                              : null,
                    ),
                    if (locked)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: CircleAvatar(
                          radius: 10,
                          backgroundColor: cf.accent,
                          child: const Icon(
                            Icons.lock,
                            size: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  filled ? entry!.name : slotLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: filled ? FontWeight.w700 : FontWeight.w500,
                    color:
                        filled ? cf.textPrimary : cf.textSecondary,
                  ),
                ),
                if (idLabel != null)
                  Text(
                    idLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      color: cf.accent,
                    ),
                  ),
                if (filled && onRemove != null)
                  TextButton(
                    onPressed: onRemove,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: cf.error,
                    ),
                    child: const Text('Remove', style: TextStyle(fontSize: 10)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OtherOfficialCard extends StatelessWidget {
  const _OtherOfficialCard({
    required this.label,
    required this.entry,
    required this.icon,
    required this.onTap,
    this.onRemove,
  });

  final String label;
  final MatchOfficialEntry? entry;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final filled = entry != null && entry!.name.isNotEmpty;
    return _OfficialSlotCard(
      slotLabel: label,
      icon: icon,
      entry: filled ? entry : null,
      onTap: onTap,
      onRemove: onRemove,
    );
  }
}
