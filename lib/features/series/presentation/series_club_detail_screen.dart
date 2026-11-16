import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_gate.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../data/models/series/series.dart';
import '../../../domain/services/series/org_competition_access.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/series_providers.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';
import 'widgets/series_player_search_screen.dart';
import 'widgets/series_ui.dart';
import 'widgets/series_user_name.dart';
import '../../../core/utils/friendly_error.dart';

class SeriesClubDetailScreen extends ConsumerStatefulWidget {
  const SeriesClubDetailScreen({
    super.key,
    required this.seriesId,
    required this.clubId,
  });
  final String seriesId;
  final String clubId;

  @override
  ConsumerState<SeriesClubDetailScreen> createState() =>
      _SeriesClubDetailScreenState();
}

class _SeriesClubDetailScreenState
    extends ConsumerState<SeriesClubDetailScreen> {
  bool _busy = false;
  String? _busyMessage;


  Future<void> _runBusy(String message, Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _busyMessage = message;
    });
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  Future<void> _requestJoin() async {
    final path =
        '/series/${widget.seriesId}/register?clubId=${widget.clubId}&join=1';
    await requireLogin(
      context: context,
      ref: ref,
      prompt: SignInPrompt.joinOrgTeam,
      returnPath: path,
      action: () async {
        if (context.mounted) context.push(path);
      },
    );
  }

  Future<void> _requestRemoval(SeriesMembershipModel member) async {
    final role = ref.read(mySeriesRoleProvider(widget.seriesId));
    final isOrgAdmin =
        role == SeriesRole.superAdmin || role == SeriesRole.seriesAdmin;
    final name = seriesPersonLabel(
      displayName: member.displayName,
      userId: member.userId,
      fallback: 'this player',
    );
    final reasonController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final canSubmit = reasonController.text.trim().isNotEmpty;
            return AlertDialog(
              title: Text(isOrgAdmin ? 'Remove player?' : 'Request player removal?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOrgAdmin
                        ? 'Remove $name from the squad? This is final.'
                        : 'Ask organization admins to remove $name from the squad. They stay on the squad, marked Removal pending, until the request is reviewed.',
                  ),
                  const SizedBox(height: AppDimens.spaceMd),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    onChanged: (_) => setLocal(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Reason (required)',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: canSubmit ? () => Navigator.pop(ctx, true) : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(ctx).colorScheme.error,
                    foregroundColor: Theme.of(ctx).colorScheme.onError,
                  ),
                  child: Text(isOrgAdmin ? 'Remove player' : 'Request removal'),
                ),
              ],
            );
          },
        );
      },
    );
    final reason = reasonController.text.trim();
    if (ok != true || reason.isEmpty) {
      reasonController.dispose();
      return;
    }
    setState(() { _busy = true; _busyMessage = isOrgAdmin ? 'Removing player…' : 'Sending request…'; });
    try {
      await ref.read(seriesFunctionsServiceProvider).submitPlayerRemovalRequest({
        'seriesId': widget.seriesId,
        'clubId': widget.clubId,
        'userId': member.userId,
        'reason': reason,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isOrgAdmin ? 'Player removed' : 'Removal request submitted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not submit: ${friendlyError(e)}')));
      }
    } finally {
      reasonController.dispose();
      if (mounted) setState(() { _busy = false; _busyMessage = null; });
    }
  }

  Future<void> _addPlayerSearch() async {
    final members = ref.read(seriesClubSquadProvider((
      seriesId: widget.seriesId,
      clubId: widget.clubId,
    ))).valueOrNull ?? const [];
    final exclude = {
      for (final m in members)
        if (m.isListedOnSquad) m.userId,
    };
    final selected = await SeriesPlayerSearchScreen.open(
      context,
      title: 'Search & add player',
      includeSelf: true,
      excludeUserIds: exclude,
    );
    if (selected == null || !mounted) return;
    await context.push<bool>(
      '/series/${widget.seriesId}/clubs/${widget.clubId}/add-player',
      extra: selected,
    );
  }

  Future<void> _viewJoinIdentity(SeriesApprovalModel approval) async {
    final registrationId = approval.metadata['registrationId']?.toString();
    if (registrationId == null || registrationId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No registration linked to this request')),
      );
      return;
    }
    try {
      final result = await ref
          .read(seriesFunctionsServiceProvider)
          .getSeriesRegistrationIdentity(
            seriesId: widget.seriesId,
            registrationId: registrationId,
          );
      if (!mounted) return;
      final identity = result['identity'];
      final pub = result['public'];
      final map = <String, dynamic>{
        if (pub is Map) ...Map<String, dynamic>.from(pub),
        if (identity is Map) ...Map<String, dynamic>.from(identity),
      };
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Registration details'),
          content: map.isEmpty
              ? const Text('No private details on file.')
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final e in map.entries)
                        if ((e.value?.toString().trim() ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '${seriesIdentityFieldLabel(e.key)}: ${e.value}',
                            ),
                          ),
                    ],
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load registration details')),
        );
      }
    }
  }

  Future<void> _clubReviewJoin(
    SeriesApprovalModel approval,
    String decision,
  ) async {
    var reason = '';
    if (decision == 'rejected') {
      final controller = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Reject registration'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Reason (required)',
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim().isNotEmpty),
              child: const Text('Reject'),
            ),
          ],
        ),
      );
      reason = controller.text.trim();
      controller.dispose();
      if (ok != true || reason.isEmpty) return;
    }
    setState(() { _busy = true; _busyMessage = decision == 'approved' ? 'Approving request…' : 'Rejecting request…'; });
    try {
      await ref.read(seriesFunctionsServiceProvider).reviewClubJoinRequest(
        seriesId: widget.seriesId,
        approvalId: approval.id,
        decision: decision,
        reason: reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              decision == 'approved'
                  ? 'Join request cleared for organization review'
                  : 'Join request declined',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Review failed: ${friendlyError(e)}')));
      }
    } finally {
      if (mounted) setState(() { _busy = false; _busyMessage = null; });
    }
  }

  Future<void> _addClubAdmin() async {
    final admins = ref.read(seriesClubAdminsProvider((
      seriesId: widget.seriesId,
      clubId: widget.clubId,
    ))).valueOrNull ?? const [];
    final exclude = {
      for (final a in admins)
        if (a.status == 'invited' || a.status == 'active') a.userId,
    };
    final selected = await SeriesPlayerSearchScreen.open(
      context,
      title: 'Add team admin',
      includeSelf: true,
      excludeUserIds: exclude,
    );
    if (selected == null) return;
    try {
      await _runBusy('Adding admin…', () async {
        await ref.read(seriesFunctionsServiceProvider).addSeriesClubAdmin(
          seriesId: widget.seriesId,
          clubId: widget.clubId,
          userId: selected.id,
          displayName: selected.displayName.isNotEmpty
              ? selected.displayName
              : selected.name,
        );
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation sent')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not add admin: ${friendlyError(e)}')));
      }
    }
  }

  Future<void> _removeClubAdmin(SeriesClubAdminModel admin) async {
    final name = seriesPersonLabel(
      displayName: admin.displayName,
      userId: admin.userId,
      fallback: 'this admin',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove admin?'),
        content: Text('Remove $name as a team admin? They will lose admin access immediately.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: const Text('Remove admin'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() { _busy = true; _busyMessage = 'Removing admin…'; });
    try {
      await ref.read(seriesFunctionsServiceProvider).removeSeriesClubAdmin(
        seriesId: widget.seriesId,
        clubId: widget.clubId,
        userId: admin.userId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Team admin removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not remove: ${friendlyError(e)}')));
      }
    } finally {
      if (mounted) setState(() { _busy = false; _busyMessage = null; });
    }
  }

  Future<void> _cancelAdminInvite(SeriesClubAdminModel admin) async {
    setState(() { _busy = true; _busyMessage = 'Cancelling invitation…'; });
    try {
      await ref.read(seriesFunctionsServiceProvider).cancelSeriesClubAdminInvite(
        seriesId: widget.seriesId,
        clubId: widget.clubId,
        userId: admin.userId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation cancelled')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not cancel: ${friendlyError(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() { _busy = false; _busyMessage = null; });
    }
  }

  Future<void> _respondOwnInvite(String decision) async {
    setState(() { _busy = true; _busyMessage = decision == 'accepted' ? 'Accepting invitation…' : 'Declining invitation…'; });
    try {
      await ref.read(seriesFunctionsServiceProvider).respondSeriesClubAdminInvite(
        seriesId: widget.seriesId,
        clubId: widget.clubId,
        decision: decision,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              decision == 'accepted' ? 'Invitation accepted' : 'Invitation declined',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e))),
        );
      }
    } finally {
      if (mounted) setState(() { _busy = false; _busyMessage = null; });
    }
  }

  Future<void> _reviewRemoval(
    SeriesApprovalModel approval,
    String decision,
  ) async {
    var reason = approval.reason;
    if (decision == 'rejected') {
      final controller = TextEditingController(text: reason);
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setLocal) {
              final canSubmit = controller.text.trim().isNotEmpty;
              return AlertDialog(
                title: const Text('Decline removal?'),
                content: TextField(
                  controller: controller,
                  maxLines: 3,
                  onChanged: (_) => setLocal(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Reason (required)',
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: canSubmit ? () => Navigator.pop(ctx, true) : null,
                    child: const Text('Decline'),
                  ),
                ],
              );
            },
          );
        },
      );
      reason = controller.text.trim();
      controller.dispose();
      if (ok != true || reason.isEmpty) return;
    }
    setState(() { _busy = true; _busyMessage = decision == 'approved' ? 'Approving request…' : 'Rejecting request…'; });
    try {
      await ref.read(seriesFunctionsServiceProvider).reviewSeriesApproval(
        seriesId: widget.seriesId,
        approvalId: approval.id,
        decision: decision,
        reason: reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              decision == 'approved' ? 'Player removed' : 'Removal request declined',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Review failed: ${friendlyError(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() { _busy = false; _busyMessage = null; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final club = ref.watch(seriesClubByIdProvider(widget.clubId));
    final squad = ref.watch(
      seriesClubSquadProvider((
        seriesId: widget.seriesId,
        clubId: widget.clubId,
      )),
    );
    final role = ref.watch(mySeriesRoleProvider(widget.seriesId));
    final clubAdminsAsync = ref.watch(
      seriesClubAdminsProvider((
        seriesId: widget.seriesId,
        clubId: widget.clubId,
      )),
    );
    final profileAsync = ref.watch(currentUserProfileProvider);
    final uid = profileAsync.valueOrNull?.id;
    final isClubAdminForThis = clubAdminsAsync.maybeWhen(
      data: (admins) =>
          admins.any((a) => a.userId == uid && a.status == 'active'),
      orElse: () => false,
    );
    final onThisSquad = squad.maybeWhen(
      data: (members) =>
          uid != null && members.any((m) => m.isListedOnSquad && m.userId == uid),
      orElse: () => false,
    );
    final canManage =
        role == SeriesRole.superAdmin ||
        role == SeriesRole.seriesAdmin ||
        isClubAdminForThis;
    // Only org staff and this team's admins may read its join queue.
    final joinPending = canManage
        ? ref.watch(
            pendingClubJoinApprovalsProvider((
              seriesId: widget.seriesId,
              clubId: widget.clubId,
            )),
          )
        : const AsyncValue<List<SeriesApprovalModel>>.data([]);
    final clubReviews = canManage
        ? ref.watch(
            pendingClubReviewApprovalsProvider((
              seriesId: widget.seriesId,
              clubId: widget.clubId,
            )),
          )
        : const AsyncValue<List<SeriesApprovalModel>>.data([]);
    final access = ref.watch(orgCompetitionAccessProvider(widget.seriesId));
    final canManageAdmins =
        role == SeriesRole.superAdmin ||
        role == SeriesRole.seriesAdmin ||
        isClubAdminForThis;
    final isOrgAdmin =
        role == SeriesRole.superAdmin || role == SeriesRole.seriesAdmin;
    final myInvite = clubAdminsAsync.maybeWhen(
      data: (admins) {
        if (uid == null) return null;
        for (final a in admins) {
          if (a.userId == uid && a.status == 'invited') return a;
        }
        return null;
      },
      orElse: () => null,
    );
    return Scaffold(
      backgroundColor: cf.background,
      appBar: const CfChromeAppBar(title: Text('Team')),
      body: Column(
        children: [
          if (_busy)
            Material(
              color: cf.surfaceElevated,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: AppDimens.spaceMd),
                    Expanded(
                      child: Text(
                        _busyMessage ?? 'Working…',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: club.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(friendlyError(e))),
        data: (item) {
          if (item == null) return const Center(child: Text('Team not found'));
          return ListView(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor:
                        cf.accent.withValues(alpha: cf.isLight ? 0.1 : 0.15),
                    backgroundImage: item.logoUrl == null
                        ? null
                        : NetworkImage(item.logoUrl!),
                    child: item.logoUrl == null
                        ? Icon(Icons.shield_outlined, size: 34, color: cf.accent)
                        : null,
                  ),
                  const SizedBox(width: AppDimens.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text(
                          item.status.label,
                          style: TextStyle(
                            color: cf.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if ((item.linkedTeamId ?? '').isNotEmpty) ...[
                const SizedBox(height: AppDimens.spaceSm),
                ListTile(
                  key: const Key('org_team_open_crickflow_team'),
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.groups_outlined, color: cf.accent),
                  title: const Text('CrickFlow team'),
                  subtitle: const Text(
                    'Plays matches anywhere in CrickFlow. Name and squad are '
                    'managed here in the org.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/teams/${item.linkedTeamId}'),
                ),
              ],
              if (item.description.isNotEmpty) ...[
                const SizedBox(height: AppDimens.spaceMd),
                Text(item.description),
              ],
              const SizedBox(height: AppDimens.spaceLg),
              if (myInvite != null) ...[
                Card(
                  key: const Key('org_team_admin_invite_banner'),
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimens.spaceMd),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('You have been invited to be a team admin.'),
                        const SizedBox(height: AppDimens.spaceSm),
                        Row(
                          children: [
                            FilledButton(
                              onPressed: _busy ? null : () => _respondOwnInvite('accepted'),
                              child: const Text('Accept'),
                            ),
                            const SizedBox(width: AppDimens.spaceSm),
                            OutlinedButton(
                              onPressed: _busy ? null : () => _respondOwnInvite('declined'),
                              child: const Text('Decline'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppDimens.spaceSm),
              ],
              if (item.isApproved &&
                  !profileAsync.isLoading &&
                  !isClubAdminForThis &&
                  !onThisSquad &&
                  !(uid != null && squad.isLoading)) ...[
                FilledButton.icon(
                  key: const Key('org_team_request_to_join'),
                  onPressed: _busy ? null : _requestJoin,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Request to join'),
                ),
                const SizedBox(height: AppDimens.spaceSm),
              ],
              if (canManage) ...[
                FilledButton.icon(
                  key: const Key('org_team_search_add_player'),
                  onPressed: _busy ? null : _addPlayerSearch,
                  icon: const Icon(Icons.person_search_outlined),
                  label: const Text('Search & add player'),
                ),
                if (access.match != OrgStartMode.none) ...[
                const SizedBox(height: AppDimens.spaceSm),
                OutlinedButton.icon(
                  onPressed: () => context.push(
                    '/series/${widget.seriesId}/propose-match'
                    '?clubId=${widget.clubId}',
                  ),
                  icon: const Icon(Icons.sports_cricket_outlined),
                  label: Text(
                    OrgCompetitionAccess.actionLabel(
                      access.match,
                      tournament: false,
                    ),
                  ),
                ),
                ],
                if (access.tournament != OrgStartMode.none) ...[
                const SizedBox(height: AppDimens.spaceSm),
                OutlinedButton.icon(
                  onPressed: () => context.push(
                    '/series/${widget.seriesId}/propose-tournament'
                    '?clubId=${widget.clubId}',
                  ),
                  icon: const Icon(Icons.emoji_events_outlined),
                  label: Text(
                    OrgCompetitionAccess.actionLabel(
                      access.tournament,
                      tournament: true,
                    ),
                  ),
                ),
                ],
                if (role == SeriesRole.superAdmin ||
                    role == SeriesRole.seriesAdmin) ...[
                  const SizedBox(height: AppDimens.spaceSm),
                  OutlinedButton.icon(
                    onPressed: () =>
                        context.push('/series/${widget.seriesId}/approvals'),
                    icon: const Icon(Icons.manage_accounts_outlined),
                    label: const Text('Pending approvals'),
                  ),
                ],
              ],
              if (canManage) ...[
                const SizedBox(height: AppDimens.spaceLg),
                Text(
                  'Join requests',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppDimens.spaceSm),
                joinPending.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text(friendlyError(e)),
                  data: (items) {
                    if (items.isEmpty) {
                      return Text(
                        'No pending join reviews.',
                        style: TextStyle(color: cf.textSecondary),
                      );
                    }
                    return Column(
                      children: items
                          .map(
                            (a) {
                              final name = seriesPersonLabel(
                                displayName:
                                    a.metadata['displayName']?.toString(),
                                userId: a.requestedBy,
                              );
                              return Card(
                                color: cf.surface,
                                child: ListTile(
                                  title: name == 'Member'
                                      ? SeriesUserName(a.requestedBy)
                                      : Text(name),
                                  subtitle: Text(
                                    seriesClubReviewLabel(
                                      a.metadata['clubReviewStatus']
                                          ?.toString(),
                                    ),
                                  ),
                                  trailing: Wrap(
                                    spacing: 4,
                                    children: [
                                      IconButton(
                                        tooltip: 'View documents',
                                        onPressed: _busy
                                            ? null
                                            : () => _viewJoinIdentity(a),
                                        icon: const Icon(Icons.badge_outlined),
                                      ),
                                      IconButton(
                                        tooltip: 'Decline',
                                        onPressed: _busy
                                            ? null
                                            : () => _clubReviewJoin(
                                                  a,
                                                  'rejected',
                                                ),
                                        icon: const Icon(Icons.close),
                                      ),
                                      IconButton(
                                        tooltip: 'Clear for organization',
                                        onPressed: _busy
                                            ? null
                                            : () => _clubReviewJoin(
                                                  a,
                                                  'approved',
                                                ),
                                        icon: const Icon(Icons.check),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                          .toList(),
                    );
                  },
                ),
              ],
              if (canManage) ...[
                const SizedBox(height: AppDimens.spaceLg),
                Text(
                  'Removal requests',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppDimens.spaceSm),
                clubReviews.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text(friendlyError(e)),
                  data: (items) {
                    final removals = items
                        .where((a) => a.targetType == SeriesApprovalTargetType.playerRemoval)
                        .toList();
                    if (removals.isEmpty) {
                      return Text(
                        'No pending removal reviews.',
                        style: TextStyle(color: cf.textSecondary),
                      );
                    }
                    return Column(
                      children: removals
                          .map(
                            (a) => ListTile(
                              title: Text(
                                seriesPersonLabel(
                                  displayName: (a.metadata['displayName'] ?? '').toString(),
                                  userId: (a.metadata['userId'] ?? '').toString(),
                                  fallback: 'Player',
                                ),
                              ),
                              subtitle: Text(
                                a.reason.isEmpty ? 'Removal pending' : a.reason,
                              ),
                              trailing: isOrgAdmin
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Decline',
                                          onPressed: _busy
                                              ? null
                                              : () => _reviewRemoval(a, 'rejected'),
                                          icon: const Icon(Icons.close),
                                        ),
                                        IconButton(
                                          tooltip: 'Approve removal',
                                          onPressed: _busy
                                              ? null
                                              : () => _reviewRemoval(a, 'approved'),
                                          icon: const Icon(Icons.check),
                                        ),
                                      ],
                                    )
                                  : const Text('Pending'),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              ],
              if (canManageAdmins) ...[
                const SizedBox(height: AppDimens.spaceLg),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Team admins',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _busy ? null : _addClubAdmin,
                      icon: const Icon(Icons.person_add_outlined),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                clubAdminsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text(friendlyError(e)),
                  data: (admins) {
                    final active =
                        admins.where((a) => a.status != 'removed').toList();
                    if (active.isEmpty) {
                      return Text(
                        'No team admins yet.',
                        style: TextStyle(color: cf.textSecondary),
                      );
                    }
                    return Column(
                      children: active
                          .map(
                            (a) {
                              final name = seriesPersonLabel(
                                displayName: a.displayName,
                                userId: a.userId,
                              );
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: cf.accent.withValues(
                                    alpha: cf.isLight ? 0.1 : 0.15,
                                  ),
                                  child: Icon(
                                    Icons.admin_panel_settings_outlined,
                                    color: cf.accent,
                                  ),
                                ),
                                title: name == 'Member'
                                    ? SeriesUserName(a.userId)
                                    : Text(name),
                                subtitle: Text(
                                  seriesAdminStatusLabel(a.status),
                                ),
                                trailing: a.status == 'invited' && canManageAdmins
                                    ? TextButton(
                                        onPressed: _busy
                                            ? null
                                            : () => _cancelAdminInvite(a),
                                        child: const Text('Cancel'),
                                      )
                                    : (isOrgAdmin && a.status == 'active'
                                        ? IconButton(
                                            tooltip: 'Remove',
                                            onPressed: _busy
                                                ? null
                                                : () => _removeClubAdmin(a),
                                            icon: const Icon(
                                              Icons.person_remove_outlined,
                                            ),
                                          )
                                        : null),
                              );
                            },
                          )
                          .toList(),
                    );
                  },
                ),
              ],
              const SizedBox(height: AppDimens.spaceLg),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Squad',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (canManage)
                    TextButton.icon(
                      key: const Key('org_team_squad_add'),
                      onPressed: _busy ? null : _addPlayerSearch,
                      icon: const Icon(Icons.person_add_outlined),
                      label: const Text('Add'),
                    ),
                ],
              ),
              const SizedBox(height: AppDimens.spaceSm),
              squad.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text(friendlyError(e)),
                data: (members) {
                  // Team admins and squad are independent lists. A person who
                  // is both an admin and a player appears in both sections.
                  final listed = members.where((m) => m.isListedOnSquad).toList();
                  return listed.isEmpty
                      ? const SeriesEmptyState(
                          icon: Icons.groups_outlined,
                          title: 'Squad not published',
                        )
                      : Column(
                          children: listed
                              .map(
                                (m) => ListTile(
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.person_outline),
                                  ),
                                  title: Text(
                                    seriesPersonLabel(
                                      displayName: m.displayName,
                                      userId: m.userId,
                                      fallback: 'Player',
                                    ),
                                  ),
                                  subtitle: Text(m.status.label),
                                  trailing: canManage &&
                                          m.status != SeriesMembershipStatus.pendingRemoval
                                      ? IconButton(
                                          tooltip: isOrgAdmin
                                              ? 'Remove player'
                                              : 'Request removal',
                                          onPressed: _busy
                                              ? null
                                              : () => _requestRemoval(m),
                                          icon: const Icon(
                                            Icons.person_remove_outlined,
                                          ),
                                        )
                                      : null,
                                ),
                              )
                              .toList(),
                        );
                },
              ),
            ],
          );
        },
      ),
          ),
        ],
      ),
    );
  }
}
