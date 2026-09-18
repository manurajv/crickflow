import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../data/models/series/series.dart';
import '../../../data/models/team_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/series_providers.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';

class SeriesClubCreateScreen extends ConsumerStatefulWidget {
  const SeriesClubCreateScreen({super.key, required this.seriesId});
  final String seriesId;

  @override
  ConsumerState<SeriesClubCreateScreen> createState() =>
      _SeriesClubCreateScreenState();
}

class _SeriesClubCreateScreenState
    extends ConsumerState<SeriesClubCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  TeamModel? _linkedTeam;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickLinkedTeam(List<TeamModel> teams) async {
    if (teams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have no CrickFlow teams yet. Create a team first, or skip this step.'),
        ),
      );
      return;
    }
    final selected = await showModalBottomSheet<TeamModel>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final cf = ctx.cf;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.spaceMd,
                  0,
                  AppDimens.spaceMd,
                  AppDimens.spaceSm,
                ),
                child: Text(
                  'Link a CrickFlow team',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: teams.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: cf.border),
                  itemBuilder: (_, i) {
                    final team = teams[i];
                    final selected = _linkedTeam?.id == team.id;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            cf.accent.withValues(alpha: cf.isLight ? 0.1 : 0.15),
                        backgroundImage: (team.profileImageUrl == null ||
                                team.profileImageUrl!.isEmpty)
                            ? null
                            : NetworkImage(team.profileImageUrl!),
                        child: (team.profileImageUrl == null ||
                                team.profileImageUrl!.isEmpty)
                            ? Text(
                                team.name.isNotEmpty
                                    ? team.name[0].toUpperCase()
                                    : '?',
                                style: TextStyle(color: cf.accent),
                              )
                            : null,
                      ),
                      title: Text(team.name),
                      subtitle: team.location.displayLabel.isNotEmpty
                          ? Text(team.location.displayLabel)
                          : null,
                      trailing: selected
                          ? Icon(Icons.check_circle, color: cf.accent)
                          : null,
                      onTap: () => Navigator.pop(ctx, team),
                    );
                  },
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );
    if (selected == null || !mounted) return;
    setState(() {
      _linkedTeam = selected;
      if (_name.text.trim().isEmpty) {
        _name.text = selected.name;
      }
    });
  }

  Future<void> _submit({
    required String orgLabel,
    required String unitLabel,
  }) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final result = await ref
          .read(seriesFunctionsServiceProvider)
          .createSeriesClub({
            'seriesId': widget.seriesId,
            'name': _name.text.trim(),
            'description': _description.text.trim(),
            if (_linkedTeam != null) 'linkedTeamId': _linkedTeam!.id,
          });
      if (!mounted) return;
      final clubId = result['clubId']?.toString();
      final autoApproved = result['autoApproved'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            autoApproved
                ? '$unitLabel added and active'
                : '$unitLabel submitted for $orgLabel admin approval',
          ),
        ),
      );
      if (clubId != null && clubId.isNotEmpty) {
        context.go('/series/${widget.seriesId}/clubs/$clubId');
      } else {
        context.pop();
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.message?.trim().isNotEmpty == true
                  ? e.message!
                  : 'Could not create club. Try again.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not create club. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final org = ref.watch(seriesByIdProvider(widget.seriesId)).valueOrNull;
    final orgLabel = org?.kind.label ?? 'Organization';
    final unitLabel = org?.memberUnitsSingular ?? 'Club';
    final teamsAsync = ref.watch(teamsProvider);
    final role = ref.watch(mySeriesRoleProvider(widget.seriesId));
    final isManager =
        role == SeriesRole.superAdmin || role == SeriesRole.seriesAdmin;

    return Scaffold(
      backgroundColor: cf.background,
      appBar: CfChromeAppBar(title: Text('Create $unitLabel')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppDimens.spaceLg),
          children: [
            if (org != null) ...[
              Text(
                isManager ? 'Add to ${org.name}' : 'Join ${org.name}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                isManager
                    ? '$unitLabel will be active immediately — no approval needed.'
                    : 'Submit a $unitLabel for $orgLabel admin approval.',
                style: TextStyle(color: cf.textSecondary),
              ),
              const SizedBox(height: AppDimens.spaceLg),
            ],
            TextFormField(
              controller: _name,
              decoration: InputDecoration(
                labelText: '$unitLabel name',
                prefixIcon: const Icon(Icons.shield_outlined),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  v == null || v.trim().length < 2
                      ? 'Enter a $unitLabel name'
                      : null,
            ),
            const SizedBox(height: AppDimens.spaceMd),
            TextFormField(
              controller: _description,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'About this club, home ground, age group…',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Text(
              'Link CrickFlow team (optional)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Pick one of your teams by name. This does not convert the team — it only links it for reference.',
              style: TextStyle(color: cf.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            teamsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => Text(
                'Could not load your teams. You can still create without linking.',
                style: TextStyle(color: cf.textSecondary),
              ),
              data: (teams) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _saving ? null : () => _pickLinkedTeam(teams),
                      icon: const Icon(Icons.groups_outlined),
                      label: Text(
                        _linkedTeam == null
                            ? 'Choose a team'
                            : 'Change linked team',
                      ),
                    ),
                    if (_linkedTeam != null) ...[
                      const SizedBox(height: AppDimens.spaceSm),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: cf.accent
                              .withValues(alpha: cf.isLight ? 0.1 : 0.15),
                          backgroundImage: (_linkedTeam!.profileImageUrl == null ||
                                  _linkedTeam!.profileImageUrl!.isEmpty)
                              ? null
                              : NetworkImage(_linkedTeam!.profileImageUrl!),
                          child: (_linkedTeam!.profileImageUrl == null ||
                                  _linkedTeam!.profileImageUrl!.isEmpty)
                              ? Text(
                                  _linkedTeam!.name.isNotEmpty
                                      ? _linkedTeam!.name[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(color: cf.accent),
                                )
                              : null,
                        ),
                        title: Text(_linkedTeam!.name),
                        subtitle: const Text('Linked CrickFlow team'),
                        trailing: IconButton(
                          tooltip: 'Remove link',
                          onPressed: _saving
                              ? null
                              : () => setState(() => _linkedTeam = null),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: AppDimens.spaceLg),
            FilledButton.icon(
              onPressed: _saving
                  ? null
                  : () => _submit(orgLabel: orgLabel, unitLabel: unitLabel),
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(isManager ? Icons.add : Icons.send_outlined),
              label: Text(
                _saving
                    ? 'Saving…'
                    : (isManager
                        ? 'Create $unitLabel'
                        : 'Submit for approval'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
