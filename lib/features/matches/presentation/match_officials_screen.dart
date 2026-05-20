import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../data/models/match_setup_draft_models.dart';
import '../../../shared/providers/start_match_draft_provider.dart';

/// Assign umpires, scorers, commentators, referee, and streamers.
class MatchOfficialsScreen extends ConsumerWidget {
  const MatchOfficialsScreen({super.key});

  static const _umpireSlots = ['1st', '2nd', '3rd', '4th'];
  static const _scorerSlots = ['1st', '2nd'];
  static const _commentatorSlots = ['1st', '2nd'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(startMatchDraftProvider);
    final setup = draft.setup;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Match officials')),
      body: ListView(
        padding: AppDimens.listPadding,
        children: [
          _OfficialSection(
            title: 'Select umpires',
            slots: _umpireSlots,
            entries: setup.umpires,
            icon: Icons.sports,
            onSlotTap: (i) => _openAdd(
              context,
              ref,
              title: 'Add an umpire',
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
            onSlotTap: (i) => _openAdd(
              context,
              ref,
              title: 'Add a scorer',
              slotLabel: _scorerSlots[i],
              type: _OfficialType.scorer,
              index: i,
              entries: setup.scorers,
            ),
            onRemove: (i) => _removeAt(ref, _OfficialType.scorer, i, setup),
          ),
          const SizedBox(height: AppDimens.spaceLg),
          _OfficialSection(
            title: 'Select commentators',
            slots: _commentatorSlots,
            entries: setup.commentators,
            icon: Icons.headset_mic_outlined,
            onSlotTap: (i) => _openAdd(
              context,
              ref,
              title: 'Add a commentator',
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
                        'slotLabel': 'Referee',
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
                    ref,
                    title: 'Add live streamer',
                    slotLabel: 'Streamer',
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
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          child: FilledButton(
            onPressed: () => context.push('/match/create/toss'),
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

  Future<void> _openAdd(
    BuildContext context,
    WidgetRef ref, {
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
  });

  final String title;
  final List<String> slots;
  final List<MatchOfficialEntry> entries;
  final IconData icon;
  final ValueChanged<int> onSlotTap;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        SizedBox(
          height: 130,
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
                onTap: () => onSlotTap(i),
                onRemove: filled ? () => onRemove(i) : null,
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
  });

  final String slotLabel;
  final IconData icon;
  final MatchOfficialEntry? entry;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final filled = entry != null && entry!.name.isNotEmpty;
    return SizedBox(
      width: 100,
      child: Material(
        color: AppColors.card,
        borderRadius: AppDimens.cardRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppDimens.cardRadius,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: AppDimens.cardRadius,
              border: Border.all(color: AppColors.border),
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
                      backgroundColor: AppColors.surfaceElevated,
                      child: filled
                          ? Text(
                              entry!.name[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : Icon(icon, color: AppColors.textSecondary),
                    ),
                    if (filled)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: CircleAvatar(
                          radius: 10,
                          backgroundColor: AppColors.gold,
                          child: Text(
                            slotLabel.replaceAll(RegExp(r'[^0-9]'), '').isEmpty
                                ? '•'
                                : slotLabel[0],
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
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
                    color: filled ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
                if (filled && onRemove != null)
                  TextButton(
                    onPressed: onRemove,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: AppColors.accentRed,
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
