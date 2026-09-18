import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../data/models/series/series.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/player_discovery_repository.dart';
import '../../../shared/providers/series_providers.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';
import 'widgets/series_ui.dart';
import 'widgets/series_user_name.dart';

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

  Future<void> _requestJoin() async {
    if (FirebaseAuth.instance.currentUser == null) {
      context.push('/login');
      return;
    }
    context.push(
      '/series/${widget.seriesId}/register'
      '?clubId=${widget.clubId}&join=1',
    );
  }

  Future<void> _requestRemoval(SeriesMembershipModel member) async {
    final reasonController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request player removal'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: 'Reason'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(seriesFunctionsServiceProvider).submitPlayerRemovalRequest({
        'seriesId': widget.seriesId,
        'clubId': widget.clubId,
        'userId': member.userId,
        'reason': reasonController.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removal request submitted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not submit: $e')));
      }
    } finally {
      reasonController.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addPlayerSearch() async {
    final selected = await showModalBottomSheet<UserModel>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _PlayerSearchSheet(),
    );
    if (selected == null || !mounted) return;
    await context.push<bool>(
      '/series/${widget.seriesId}/clubs/${widget.clubId}/add-player',
      extra: selected,
    );
  }

  Future<void> _clubReviewJoin(
    SeriesApprovalModel approval,
    String decision,
  ) async {
    setState(() => _busy = true);
    try {
      await ref.read(seriesFunctionsServiceProvider).reviewClubJoinRequest(
        seriesId: widget.seriesId,
        approvalId: approval.id,
        decision: decision,
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
        ).showSnackBar(SnackBar(content: Text('Review failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addClubAdmin() async {
    final selected = await showModalBottomSheet<UserModel>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _PlayerSearchSheet(),
    );
    if (selected == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(seriesFunctionsServiceProvider).addSeriesClubAdmin(
        seriesId: widget.seriesId,
        clubId: widget.clubId,
        userId: selected.id,
        displayName: selected.displayName.isNotEmpty
            ? selected.displayName
            : selected.name,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Club admin added')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not add admin: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeClubAdmin(SeriesClubAdminModel admin) async {
    setState(() => _busy = true);
    try {
      await ref.read(seriesFunctionsServiceProvider).removeSeriesClubAdmin(
        seriesId: widget.seriesId,
        clubId: widget.clubId,
        userId: admin.userId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Club admin removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not remove: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
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
    final joinPending = ref.watch(
      pendingClubJoinApprovalsProvider((
        seriesId: widget.seriesId,
        clubId: widget.clubId,
      )),
    );
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final isClubAdminForThis = clubAdminsAsync.maybeWhen(
      data: (admins) =>
          admins.any((a) => a.userId == uid && a.status == 'active'),
      orElse: () => false,
    );
    final canManage =
        role == SeriesRole.superAdmin ||
        role == SeriesRole.seriesAdmin ||
        isClubAdminForThis;
    final canManageAdmins =
        role == SeriesRole.superAdmin ||
        role == SeriesRole.seriesAdmin ||
        isClubAdminForThis;
    return Scaffold(
      backgroundColor: cf.background,
      appBar: const CfChromeAppBar(title: Text('Club')),
      body: club.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (item) {
          if (item == null) return const Center(child: Text('Club not found'));
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
              if (item.description.isNotEmpty) ...[
                const SizedBox(height: AppDimens.spaceMd),
                Text(item.description),
              ],
              const SizedBox(height: AppDimens.spaceLg),
              if (item.isApproved)
                FilledButton.icon(
                  onPressed: _busy ? null : _requestJoin,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Register & request to join'),
                ),
              if (canManage) ...[
                const SizedBox(height: AppDimens.spaceSm),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _addPlayerSearch,
                  icon: const Icon(Icons.person_search_outlined),
                  label: Text(
                    role == SeriesRole.superAdmin ||
                            role == SeriesRole.seriesAdmin
                        ? 'Search & add player'
                        : 'Search & request add player',
                  ),
                ),
                const SizedBox(height: AppDimens.spaceSm),
                OutlinedButton.icon(
                  onPressed: () => context.push(
                    '/series/${widget.seriesId}/propose-match'
                    '?clubId=${widget.clubId}',
                  ),
                  icon: const Icon(Icons.sports_cricket_outlined),
                  label: const Text('Propose match'),
                ),
                const SizedBox(height: AppDimens.spaceSm),
                OutlinedButton.icon(
                  onPressed: () => context.push(
                    '/series/${widget.seriesId}/propose-tournament'
                    '?clubId=${widget.clubId}',
                  ),
                  icon: const Icon(Icons.emoji_events_outlined),
                  label: const Text('Propose tournament'),
                ),
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
                  error: (e, _) => Text('$e'),
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
              if (canManageAdmins) ...[
                const SizedBox(height: AppDimens.spaceLg),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Club admins',
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
                  error: (e, _) => Text('$e'),
                  data: (admins) {
                    final active =
                        admins.where((a) => a.status != 'removed').toList();
                    if (active.isEmpty) {
                      return Text(
                        'No club admins yet.',
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
                                trailing:
                                    role == SeriesRole.superAdmin ||
                                            role == SeriesRole.seriesAdmin
                                        ? IconButton(
                                            tooltip: 'Remove',
                                            onPressed: _busy
                                                ? null
                                                : () => _removeClubAdmin(a),
                                            icon: const Icon(
                                              Icons.person_remove_outlined,
                                            ),
                                          )
                                        : null,
                              );
                            },
                          )
                          .toList(),
                    );
                  },
                ),
              ],
              const SizedBox(height: AppDimens.spaceLg),
              Text('Squad', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppDimens.spaceSm),
              squad.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('$e'),
                data: (members) {
                  final active = members.where((m) => m.isActive).toList();
                  return active.isEmpty
                      ? const SeriesEmptyState(
                          icon: Icons.groups_outlined,
                          title: 'Squad not published',
                        )
                      : Column(
                          children: active
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
                                  trailing: canManage
                                      ? IconButton(
                                          tooltip: 'Request removal',
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
    );
  }
}

class _PlayerSearchSheet extends StatefulWidget {
  const _PlayerSearchSheet();

  @override
  State<_PlayerSearchSheet> createState() => _PlayerSearchSheetState();
}

class _PlayerSearchSheetState extends State<_PlayerSearchSheet> {
  final _query = TextEditingController();
  final _repo = PlayerDiscoveryRepository();
  List<UserModel> _results = const [];
  bool _loading = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.trim().length < 2) {
      setState(() => _results = const []);
      return;
    }
    setState(() => _loading = true);
    try {
      final list = await _repo.searchPlayers(
        query: q,
        currentUserId: FirebaseAuth.instance.currentUser?.uid,
      );
      if (mounted) setState(() => _results = list);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceMd + bottom,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.65,
        child: Column(
          children: [
            TextField(
              controller: _query,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Search by name or CrickFlow Player ID',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _search,
            ),
            const SizedBox(height: AppDimens.spaceSm),
            if (_loading) const LinearProgressIndicator(),
            Expanded(
              child: _results.isEmpty
                  ? const Center(child: Text('Type a name to find players'))
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (_, i) {
                        final u = _results[i];
                        final name = u.displayName.isNotEmpty
                            ? u.displayName
                            : u.name;
                        final subtitle = (u.playerId != null &&
                                u.playerId!.trim().isNotEmpty)
                            ? u.playerId!
                            : (u.location.displayLabel.isNotEmpty
                                ? u.location.displayLabel
                                : null);
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: u.photoUrl == null
                                ? null
                                : NetworkImage(u.photoUrl!),
                            child: u.photoUrl == null
                                ? const Icon(Icons.person_outline)
                                : null,
                          ),
                          title: Text(name),
                          subtitle:
                              subtitle == null ? null : Text(subtitle),
                          onTap: () => Navigator.pop(context, u),
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
