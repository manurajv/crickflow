import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../config/routes/app_router.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/cf_colors.dart';
import '../../../../../core/utils/cf_team_id_format.dart';
import '../../../../../core/utils/deep_link_utils.dart';
import '../../../../../data/models/team_model.dart';
import '../../../../../data/models/tournament/tournament_team_request_model.dart';
import '../../../../../data/models/tournament_model.dart';
import '../../../../../shared/providers/providers.dart';
import '../../../../../shared/providers/tournament_providers.dart';
import '../../../../../shared/providers/tournament_team_request_provider.dart';
import '../../../../../shared/widgets/cf_button.dart';
import '../../../../../shared/widgets/match_list_card.dart';
import '../../../../teams/presentation/widgets/team_list_tile.dart';
import '../tournament_qr_view.dart';
import 'tournament_team_confirm_sheet.dart';

Future<void> showAddTeamToTournamentSheet({
  required BuildContext context,
  required WidgetRef ref,
  required TournamentModel tournament,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => AddTeamBottomSheet(
      tournament: tournament,
      hostContext: context,
    ),
  );
}

Future<TeamModel?> showTournamentTeamSearchSheet({
  required BuildContext context,
  required List<TeamModel> teams,
}) {
  return showModalBottomSheet<TeamModel>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _TeamSearchSheet(teams: teams),
  );
}

class AddTeamBottomSheet extends ConsumerWidget {
  const AddTeamBottomSheet({
    super.key,
    required this.tournament,
    required this.hostContext,
  });

  final TournamentModel tournament;
  final BuildContext hostContext;

  String get _joinLink =>
      DeepLinkUtils.hostedTournamentJoinUri(tournament.id).toString();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Padding(
          padding: AppDimens.screenPadding,
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppDimens.spaceMd),
                  decoration: BoxDecoration(
                    color: cf.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Text(
                'Add teams to tournament',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: AppDimens.spaceLg),
              _OptionCard(
                icon: Icons.link_outlined,
                title: 'Invite teams',
                subtitle:
                    'Share your tournament link with team owners and captains.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SelectableText(
                      _joinLink,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cf.textSecondary,
                          ),
                    ),
                    const SizedBox(height: AppDimens.spaceSm),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _joinLink));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Link copied')),
                              );
                            },
                            icon: const Icon(Icons.copy_outlined, size: 18),
                            label: const Text('Copy'),
                          ),
                        ),
                        const SizedBox(width: AppDimens.spaceSm),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Share.share(
                              'Join ${tournament.name} on CrickFlow\n$_joinLink',
                              subject: tournament.name,
                            ),
                            icon: const Icon(Icons.share_outlined, size: 18),
                            label: const Text('Share'),
                          ),
                        ),
                        const SizedBox(width: AppDimens.spaceSm),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _shareWhatsApp(context),
                            icon: const Icon(Icons.chat_outlined, size: 18),
                            label: const Text('WhatsApp'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _OptionCard(
                icon: Icons.search_outlined,
                title: 'Select existing team',
                subtitle: 'Search by team name or team code.',
                child: CfButton(
                  label: 'Search teams',
                  isOutlined: true,
                  compact: true,
                  onPressed: () => _pickExistingTeam(context, ref),
                ),
              ),
              _OptionCard(
                icon: Icons.group_add_outlined,
                title: 'Create new team',
                subtitle:
                    'Use the main create-team flow, then invite the team here.',
                child: CfButton(
                  label: 'Create team',
                  isOutlined: true,
                  compact: true,
                  onPressed: () => _createTeam(context),
                ),
              ),
              _OptionCard(
                icon: Icons.qr_code_2_outlined,
                title: 'Join using QR',
                subtitle: 'Captains scan this QR to request tournament entry.',
                child: Column(
                  children: [
                    TournamentQrView(
                      tournament: tournament,
                      showCode: false,
                      size: 140,
                    ),
                    const SizedBox(height: AppDimens.spaceSm),
                    Text(
                      _joinLink,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: cf.textMuted,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _shareWhatsApp(BuildContext context) async {
    final text = Uri.encodeComponent(
      'Join ${tournament.name} on CrickFlow\n$_joinLink',
    );
    final uri = Uri.parse('https://wa.me/?text=$text');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp')),
      );
    }
  }

  Future<void> _pickExistingTeam(
    BuildContext sheetContext,
    WidgetRef ref,
  ) async {
    Navigator.pop(sheetContext);

    final teams = await ref.read(allTeamsProvider.future);
    final rootContext = rootNavigatorKey.currentContext ?? hostContext;
    if (!rootContext.mounted) return;

    if (teams.isEmpty) {
      ScaffoldMessenger.of(rootContext).showSnackBar(
        const SnackBar(content: Text('No teams found in CrickFlow yet')),
      );
      return;
    }

    final picked = await showTournamentTeamSearchSheet(
      context: rootContext,
      teams: teams,
    );
    if (picked == null || !rootContext.mounted) return;

    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    final freshTournament =
        await ref.read(tournamentProvider(tournament.id).future);
    if (freshTournament == null || !rootContext.mounted) return;

    try {
      final result = await ref
          .read(tournamentTeamRequestRepositoryProvider)
          .createInvitation(
            tournament: freshTournament,
            team: picked,
            organizerUserId: uid,
          );
      ref.invalidate(tournamentTeamRequestsProvider(tournament.id));
      ref.invalidate(tournamentProvider(tournament.id));
      ref.invalidate(allTeamsProvider);
      ref.invalidate(teamByIdProvider(picked.id));
      if (!rootContext.mounted) return;

      rootContext.go('/tournaments/${freshTournament.id}/teams');

      if (result.status == TournamentTeamRequestStatus.approved) {
        await showTournamentTeamAddedSheet(
          context: rootContext,
          title: 'Team added',
          message: '${picked.name} is now in ${freshTournament.name}.',
          sectionHint: 'See them under Approved teams below.',
        );
      } else {
        await showTournamentTeamAddedSheet(
          context: rootContext,
          title: 'Invitation sent',
          message:
              '${picked.name} has been invited to ${freshTournament.name}.',
          sectionHint: 'Track status under Invited teams below.',
        );
      }
    } catch (e) {
      if (!rootContext.mounted) return;
      ScaffoldMessenger.of(rootContext).showSnackBar(
        SnackBar(
          content: Text('Could not add team: $e'),
          backgroundColor: Theme.of(rootContext).colorScheme.error,
        ),
      );
    }
  }

  void _createTeam(BuildContext context) {
    Navigator.pop(context);
    final tournamentId = Uri.encodeComponent(tournament.id);
    context.push('/teams/create?tournamentId=$tournamentId');
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimens.spaceMd),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cf.border),
      ),
      child: Padding(
        padding: AppDimens.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: cf.accent),
                const SizedBox(width: AppDimens.spaceSm),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cf.textSecondary,
                  ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            child,
          ],
        ),
      ),
    );
  }
}

class _TeamSearchSheet extends StatefulWidget {
  const _TeamSearchSheet({required this.teams});

  final List<TeamModel> teams;

  @override
  State<_TeamSearchSheet> createState() => _TeamSearchSheetState();
}

class _TeamSearchSheetState extends State<_TeamSearchSheet> {
  final _query = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _query.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final availableHeight =
        MediaQuery.sizeOf(context).height - bottomInset;
    final sheetHeight = (availableHeight * 0.92).clamp(320.0, availableHeight);
    final q = _query.text.trim().toLowerCase();
    final filtered = widget.teams.where((team) {
      if (q.isEmpty) return true;
      final code = CfTeamIdFormat.normalize(team.teamCode ?? '').toLowerCase();
      return team.name.toLowerCase().contains(q) || code.contains(q);
    }).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: sheetHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                AppDimens.spaceMd,
                AppDimens.spaceMd,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: AppDimens.spaceMd),
                      decoration: BoxDecoration(
                        color: cf.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Text(
                    'Search teams',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: AppDimens.spaceMd),
                  TextField(
                    controller: _query,
                    focusNode: _focusNode,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'Team name or code',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Expanded(
              child: filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(AppDimens.spaceLg),
                      child: MatchListEmptyState(
                        message: 'No teams match your search',
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.only(
                        left: AppDimens.spaceMd,
                        right: AppDimens.spaceMd,
                        bottom: MediaQuery.paddingOf(context).bottom +
                            AppDimens.spaceMd,
                      ),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final team = filtered[i];
                        return ListTile(
                          leading: TeamLogoAvatar(team: team, size: 44),
                          title: Text(team.name),
                          subtitle: team.teamCode != null
                              ? Text(
                                  CfTeamIdFormat.displayLabel(team.teamCode),
                                )
                              : null,
                          onTap: () => Navigator.pop(context, team),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
