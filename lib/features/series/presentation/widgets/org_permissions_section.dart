import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../domain/services/series/org_competition_access.dart';
import '../../../../shared/providers/series_providers.dart';

/// Org settings › Permissions: who may propose a match / a tournament
/// (independently), whether each role's request waits for an org admin, and
/// whether walk-in players are allowed. Owner only (the server enforces it in
/// `updateSeriesCompetitionPolicy`).
class OrgPermissionsSection extends ConsumerStatefulWidget {
  const OrgPermissionsSection({super.key, required this.seriesId});
  final String seriesId;

  @override
  ConsumerState<OrgPermissionsSection> createState() =>
      _OrgPermissionsSectionState();
}

class _OrgPermissionsSectionState extends ConsumerState<OrgPermissionsSection> {
  OrgCompetitionPolicy? _draft;
  OrgCompetitionPolicy? _saved;
  bool _saving = false;

  bool get _dirty => _draft != null && _saved != null && _draft != _saved;

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(seriesFunctionsServiceProvider)
          .updateSeriesCompetitionPolicy(
            seriesId: widget.seriesId,
            policy: draft.toMap(),
          );
      if (!mounted) return;
      setState(() => _saved = draft);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissions saved')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save permissions: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _update(OrgCompetitionPolicy next) => setState(() => _draft = next);

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final live = ref.watch(orgCompetitionPolicyProvider(widget.seriesId));
    final loaded = live.valueOrNull;
    if (loaded != null && _draft == null) {
      _draft = loaded;
      _saved = loaded;
    }
    final policy = _draft;
    if (policy == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppDimens.spaceMd),
        child: LinearProgressIndicator(),
      );
    }

    return Column(
      key: const Key('org_permissions_section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Permissions', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppDimens.spaceXs),
        Text(
          'The owner and org admins can always start matches and tournaments '
          'directly. Choose who else can propose each one, and whether their '
          'requests need an org admin to approve them.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: cf.textSecondary),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        _KindPermissions(
          kind: 'match',
          title: 'Matches',
          noun: 'matches',
          access: policy.matchProposeAccess,
          teamAdminsNeedApproval: policy.matchTeamAdminsNeedApproval,
          playersNeedApproval: policy.matchPlayersNeedApproval,
          onAccess: (v) => _update(policy.copyWith(matchProposeAccess: v)),
          onTeamAdmins: (v) =>
              _update(policy.copyWith(matchTeamAdminsNeedApproval: v)),
          onPlayers: (v) =>
              _update(policy.copyWith(matchPlayersNeedApproval: v)),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        _KindPermissions(
          kind: 'tournament',
          title: 'Tournaments',
          noun: 'tournaments',
          access: policy.tournamentProposeAccess,
          teamAdminsNeedApproval: policy.tournamentTeamAdminsNeedApproval,
          playersNeedApproval: policy.tournamentPlayersNeedApproval,
          onAccess: (v) =>
              _update(policy.copyWith(tournamentProposeAccess: v)),
          onTeamAdmins: (v) =>
              _update(policy.copyWith(tournamentTeamAdminsNeedApproval: v)),
          onPlayers: (v) =>
              _update(policy.copyWith(tournamentPlayersNeedApproval: v)),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        Text('Walk-in players',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                )),
        SwitchListTile(
          key: const Key('org_allow_walk_ins'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Allow walk-in players'),
          subtitle: Text(
            policy.allowWalkIns
                ? 'Guests without a CrickFlow account can be added to a match '
                    'squad. They never join an org team and are left out of '
                    'rankings.'
                : 'Org matches and tournaments can only use players with a '
                    'CrickFlow account.',
          ),
          value: policy.allowWalkIns,
          onChanged: (v) => _update(policy.copyWith(allowWalkIns: v)),
        ),
        const SizedBox(height: AppDimens.spaceXs),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            key: const Key('org_permissions_save'),
            onPressed: (_dirty && !_saving) ? _save : null,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lock_outline),
            label: Text(_saving ? 'Saving…' : 'Save permissions'),
          ),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        const Divider(),
        const SizedBox(height: AppDimens.spaceSm),
      ],
    );
  }
}

/// Who can propose [noun], and the approval switch for each allowed role.
class _KindPermissions extends StatelessWidget {
  const _KindPermissions({
    required this.kind,
    required this.title,
    required this.noun,
    required this.access,
    required this.teamAdminsNeedApproval,
    required this.playersNeedApproval,
    required this.onAccess,
    required this.onTeamAdmins,
    required this.onPlayers,
  });

  final String kind;
  final String title;
  final String noun;
  final OrgProposeAccess access;
  final bool teamAdminsNeedApproval;
  final bool playersNeedApproval;
  final ValueChanged<OrgProposeAccess> onAccess;
  final ValueChanged<bool> onTeamAdmins;
  final ValueChanged<bool> onPlayers;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Column(
      key: Key('org_permissions_$kind'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(
          'Who can start $noun',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: cf.textSecondary),
        ),
        const SizedBox(height: AppDimens.spaceXs),
        for (final option in OrgProposeAccess.values)
          _AccessTile(
            tileKey: Key('org_${kind}_access_${option.name}'),
            access: option,
            noun: noun,
            selected: access == option,
            onTap: () => onAccess(option),
          ),
        if (access != OrgProposeAccess.admins)
          SwitchListTile(
            key: Key('org_${kind}_team_admins_approval'),
            contentPadding: EdgeInsets.zero,
            title: Text('Team admin $noun need approval'),
            subtitle: Text(
              teamAdminsNeedApproval
                  ? 'An org admin approves them first.'
                  : 'Team admins start them directly.',
              style: TextStyle(color: cf.textSecondary),
            ),
            value: teamAdminsNeedApproval,
            onChanged: onTeamAdmins,
          ),
        if (access == OrgProposeAccess.everyone)
          SwitchListTile(
            key: Key('org_${kind}_players_approval'),
            contentPadding: EdgeInsets.zero,
            title: Text('Player $noun need approval'),
            subtitle: Text(
              playersNeedApproval
                  ? 'An org admin approves them first.'
                  : 'Players start them directly.',
              style: TextStyle(color: cf.textSecondary),
            ),
            value: playersNeedApproval,
            onChanged: onPlayers,
          ),
      ],
    );
  }
}

class _AccessTile extends StatelessWidget {
  const _AccessTile({
    required this.tileKey,
    required this.access,
    required this.noun,
    required this.selected,
    required this.onTap,
  });

  final Key tileKey;
  final OrgProposeAccess access;
  final String noun;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceXs),
      child: Material(
        color: selected
            ? cf.accent.withValues(alpha: cf.isLight ? 0.08 : 0.14)
            : cf.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: tileKey,
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(AppDimens.spaceSm + 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? cf.accent : cf.border,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected ? cf.accent : cf.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: AppDimens.spaceSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        access.label,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        access.describe(noun),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cf.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
