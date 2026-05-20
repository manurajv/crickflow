import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/providers/start_match_draft_provider.dart';

enum _RoleTab { captain, wicketKeeper }

/// Captain and wicket-keeper from the playing squad (reference UI).
class MatchTeamRolesScreen extends ConsumerStatefulWidget {
  const MatchTeamRolesScreen({
    super.key,
    required this.teamSlot,
  });

  final String teamSlot;

  bool get isTeamA => teamSlot == 'a';

  @override
  ConsumerState<MatchTeamRolesScreen> createState() =>
      _MatchTeamRolesScreenState();
}

class _MatchTeamRolesScreenState extends ConsumerState<MatchTeamRolesScreen> {
  _RoleTab _tab = _RoleTab.captain;
  String? _captainId;
  String? _wicketKeeperId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final setup = ref.read(startMatchDraftProvider).setup;
      setState(() {
        if (widget.isTeamA) {
          _captainId = setup.teamACaptainId;
          _wicketKeeperId = setup.teamAWicketKeeperId;
        } else {
          _captainId = setup.teamBCaptainId;
          _wicketKeeperId = setup.teamBWicketKeeperId;
        }
      });
    });
  }

  void _onNext() {
    if (_captainId == null || _captainId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a captain')),
      );
      return;
    }
    if (_wicketKeeperId == null || _wicketKeeperId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a wicket keeper')),
      );
      return;
    }
    ref.read(startMatchDraftProvider.notifier).setTeamRoles(
          isTeamA: widget.isTeamA,
          captainId: _captainId!,
          wicketKeeperId: _wicketKeeperId!,
        );

    if (widget.isTeamA) {
      context.push('/match/create/squad/b');
    } else {
      context.push('/match/create/officials');
    }
  }

  String? _selectedForTab() =>
      _tab == _RoleTab.captain ? _captainId : _wicketKeeperId;

  void _selectPlayer(String id) {
    setState(() {
      if (_tab == _RoleTab.captain) {
        _captainId = id;
      } else {
        _wicketKeeperId = id;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(startMatchDraftProvider);
    final setup = draft.setup;
    final squadIds = setup.squadIdsForTeam(widget.isTeamA);
    final names = setup.squadNamesForTeam(widget.isTeamA);
    final teamName =
        widget.isTeamA ? draft.resolvedTeamAName : draft.resolvedTeamBName;

    if (squadIds.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(teamName)),
        body: const Center(child: Text('Select squad first')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Captain & wicket keeper'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppDimens.spaceMd),
            child: Center(
              child: Text(
                teamName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.gold,
                ),
              ),
            ),
          ),
        ],
      ),
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
            child: Row(
              children: [
                Expanded(
                  child: _RoleChip(
                    label: 'Captain',
                    selected: _tab == _RoleTab.captain,
                    onTap: () => setState(() => _tab = _RoleTab.captain),
                  ),
                ),
                const SizedBox(width: AppDimens.spaceSm),
                Expanded(
                  child: _RoleChip(
                    label: 'Wicket keeper',
                    selected: _tab == _RoleTab.wicketKeeper,
                    onTap: () =>
                        setState(() => _tab = _RoleTab.wicketKeeper),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: AppDimens.listPadding,
              itemCount: squadIds.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppDimens.spaceSm),
              itemBuilder: (_, i) {
                final id = squadIds[i];
                final name = names[id] ?? 'Player';
                final selected = _selectedForTab() == id;
                return _RolePlayerTile(
                  name: name,
                  selected: selected,
                  onTap: () => _selectPlayer(id),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.spaceMd),
              child: FilledButton(
                onPressed: _onNext,
                style: FilledButton.styleFrom(
                  minimumSize:
                      const Size(double.infinity, AppDimens.buttonHeightLarge),
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Next'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({
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
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? AppColors.gold : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _RolePlayerTile extends StatelessWidget {
  const _RolePlayerTile({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: AppDimens.cardRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppDimens.cardRadius,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppDimens.cardRadius,
            border: Border.all(
              color: selected ? AppColors.gold : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceMd,
            vertical: AppDimens.spaceSm,
          ),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.surfaceElevated,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (selected)
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.white),
                    ),
                ],
              ),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
