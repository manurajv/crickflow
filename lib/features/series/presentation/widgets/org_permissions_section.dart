import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../domain/services/series/org_competition_access.dart';
import '../../../../shared/providers/series_providers.dart';

/// Org settings › Permissions: who may propose a match or tournament, and
/// whether those proposals need the org's approval. Owner only (the server
/// enforces it in `updateSeriesCompetitionPolicy`).
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
          'directly. Choose who else can propose them.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: cf.textSecondary),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        for (final option in OrgProposeAccess.values)
          _AccessTile(
            access: option,
            selected: policy.proposeAccess == option,
            onTap: () => setState(
              () => _draft = policy.copyWith(proposeAccess: option),
            ),
          ),
        const SizedBox(height: AppDimens.spaceXs),
        SwitchListTile(
          key: const Key('org_match_needs_approval'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Match proposals need approval'),
          subtitle: const Text('Off: team proposals are approved instantly.'),
          value: policy.matchRequestsNeedApproval,
          onChanged: (v) => setState(
            () => _draft = policy.copyWith(matchRequestsNeedApproval: v),
          ),
        ),
        SwitchListTile(
          key: const Key('org_tournament_needs_approval'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Tournament proposals need approval'),
          subtitle: const Text('Off: team proposals are approved instantly.'),
          value: policy.tournamentRequestsNeedApproval,
          onChanged: (v) => setState(
            () => _draft = policy.copyWith(tournamentRequestsNeedApproval: v),
          ),
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

class _AccessTile extends StatelessWidget {
  const _AccessTile({
    required this.access,
    required this.selected,
    required this.onTap,
  });

  final OrgProposeAccess access;
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
          key: Key('org_access_${access.name}'),
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
                        access.description,
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
