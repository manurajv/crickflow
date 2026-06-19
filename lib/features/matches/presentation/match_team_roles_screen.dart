import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../shared/providers/start_match_draft_provider.dart';
import '../../../shared/widgets/scoring_ui_kit.dart';
import '../../../shared/widgets/start_match_ui.dart';

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
      context.push('/match/create/officials?wizard=1');
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
    final cf = context.cf;
    final draft = ref.watch(startMatchDraftProvider);
    final setup = draft.setup;
    final squad = setup.playingPlayersForTeam(widget.isTeamA);
    final teamName =
        widget.isTeamA ? draft.resolvedTeamAName : draft.resolvedTeamBName;

    if (squad.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(teamName)),
        body: const Center(child: Text('Select squad first')),
      );
    }

    return Scaffold(
      backgroundColor: cf.background,
      appBar: AppBar(
        title: const Text('Captain & wicket keeper'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppDimens.spaceMd),
            child: Center(
              child: Text(
                teamName,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: cf.accent,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const StartMatchFlowProgress(currentIndex: StartMatchFlowStep.roles),
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
              itemCount: squad.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppDimens.spaceSm),
              itemBuilder: (_, i) {
                final player = squad[i];
                final selected = _selectedForTab() == player.id;
                return _RolePlayerTile(
                  name: player.name,
                  photoUrl: player.photoUrl,
                  selected: selected,
                  onTap: () => _selectPlayer(player.id),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.spaceMd),
              child: FilledButton(
                onPressed: _onNext,
                style: ScoringUiKit.primaryButtonStyle(context).copyWith(
                  minimumSize: WidgetStateProperty.all(
                    const Size(double.infinity, AppDimens.buttonHeightLarge),
                  ),
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
    final cf = context.cf;
    return Material(
      color: selected ? cf.accent : cf.sectionBackground,
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
              color: selected ? cf.accent : cf.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : cf.textSecondary,
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
    this.photoUrl,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String? photoUrl;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;

    return Material(
      color: cf.card,
      borderRadius: AppDimens.cardRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppDimens.cardRadius,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppDimens.cardRadius,
            border: Border.all(
              color: selected ? cf.accent : cf.border,
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
                    backgroundColor: cf.sectionBackground,
                    backgroundImage: hasPhoto
                        ? CachedNetworkImageProvider(photoUrl!)
                        : null,
                    child: hasPhoto
                        ? null
                        : Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: cf.textSecondary,
                            ),
                          ),
                  ),
                  if (selected)
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: cf.accent.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check, color: cf.onAccent, size: 28),
                    ),
                ],
              ),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: cf.textPrimary,
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
