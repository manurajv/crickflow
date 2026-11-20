import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/friendly_error.dart';
import '../../../data/models/series/series.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/series_providers.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';
import 'widgets/series_document_image.dart';
import 'widgets/series_ui.dart';
import 'widgets/series_user_name.dart';

/// Request detail for org/team join (and registration) reviews.
/// Opened from push, the inbox, and approval queues.
class SeriesJoinRequestDetailScreen extends ConsumerStatefulWidget {
  const SeriesJoinRequestDetailScreen({
    super.key,
    required this.seriesId,
    required this.approvalId,
  });

  final String seriesId;
  final String approvalId;

  @override
  ConsumerState<SeriesJoinRequestDetailScreen> createState() =>
      _SeriesJoinRequestDetailScreenState();
}

class _SeriesJoinRequestDetailScreenState
    extends ConsumerState<SeriesJoinRequestDetailScreen> {
  Map<String, dynamic>? _payload;
  Object? _loadError;
  bool _loading = true;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final result = await ref
          .read(seriesFunctionsServiceProvider)
          .getSeriesRegistrationIdentity(
            seriesId: widget.seriesId,
            approvalId: widget.approvalId,
          );
      if (!mounted) return;
      setState(() {
        _payload = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _loading = false;
      });
    }
  }

  Map<String, dynamic> _map(String key) {
    final raw = _payload?[key];
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  String _str(Map<String, dynamic> map, String key) =>
      map[key]?.toString().trim() ?? '';

  Future<void> _review({required bool approve, required bool clubScope}) async {
    if (_acting) return;
    var reason = '';
    if (!approve) {
      final r = await askRejectionReason(context);
      if (r == null) return;
      reason = r;
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Approve request?'),
          content: Text(
            clubScope
                ? 'Clear this registration for organization review?'
                : 'Approve this player onto the team?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Approve'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _acting = true);
    try {
      if (clubScope) {
        await ref
            .read(seriesFunctionsServiceProvider)
            .reviewClubJoinRequest(
              seriesId: widget.seriesId,
              approvalId: widget.approvalId,
              decision: approve ? 'approved' : 'rejected',
              reason: reason,
            );
      } else {
        await ref
            .read(seriesFunctionsServiceProvider)
            .reviewSeriesApproval(
              seriesId: widget.seriesId,
              approvalId: widget.approvalId,
              decision: approve ? 'approved' : 'rejected',
              reason: reason,
            );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approve ? 'Request approved' : 'Request rejected'),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final approvalAsync = ref.watch(
      seriesApprovalByIdProvider((
        seriesId: widget.seriesId,
        approvalId: widget.approvalId,
      )),
    );
    final approval = approvalAsync.valueOrNull;
    final role = ref.watch(mySeriesRoleProvider(widget.seriesId));
    final pub = _map('public');
    final identity = _map('identity');
    final media = _map('media');
    final request = _map('request');

    final displayName = _str(pub, 'fullName');
    final crickFlowId = _str(pub, 'crickFlowPlayerId');
    final teamName = _str(pub, 'teamName');
    final orgName = _str(pub, 'orgName');
    final nationalId = _str(identity, 'nationalId');
    final passport = _str(identity, 'passportNumber');
    final phone = _str(pub, 'phoneNumber');
    final address = _str(pub, 'address');
    final dob = _str(pub, 'dateOfBirth');
    final custom = pub['customFields'] is Map
        ? Map<String, dynamic>.from(pub['customFields'] as Map)
        : <String, dynamic>{};
    final statusRaw = approval?.status.name ?? _str(request, 'status');
    final status =
        approval?.status ??
        SeriesApprovalStatus.parse(statusRaw.isEmpty ? 'pending' : statusRaw);
    final clubReview =
        approval?.metadata['clubReviewStatus']?.toString() ??
        _str(request, 'clubReviewStatus');
    final submitted =
        approval?.submittedAt ??
        approval?.requestedAt ??
        DateTime.tryParse(
          _str(pub, 'submittedAt').isEmpty
              ? _str(request, 'submittedAt')
              : _str(pub, 'submittedAt'),
        );
    final reason = (approval?.reason ?? _str(request, 'reason')).trim();
    final photoUrl = _str(media, 'profilePhotoUrl');

    final uid = ref.watch(currentUserProfileProvider).valueOrNull?.id;
    final clubId = approval?.clubId ?? '';
    final isClubAdmin = clubId.isEmpty
        ? false
        : (ref
                      .watch(
                        seriesClubAdminsProvider((
                          seriesId: widget.seriesId,
                          clubId: clubId,
                        )),
                      )
                      .valueOrNull ??
                  const [])
              .any((a) => a.userId == uid && a.status == 'active');
    final isOrgAdmin =
        role == SeriesRole.superAdmin || role == SeriesRole.seriesAdmin;
    final targetTypeName =
        approval?.targetType.name ?? _str(request, 'targetType');
    final isAdd = targetTypeName == 'playerAdd' ||
        targetTypeName == 'playerRegistration';
    final pending = status == SeriesApprovalStatus.pending;
    final scope = SeriesRequestActionScope.resolve(
      pending: pending,
      isClubAdmin: isClubAdmin,
      isOrgAdmin: isOrgAdmin,
      isSuperAdmin: role == SeriesRole.superAdmin,
      targetType: targetTypeName,
      clubReviewStatus: clubReview,
    );
    final clubScope = scope.clubScope;
    final canAct = !_acting && scope.canAct;
    final playerUserId = approval?.metadata['userId']?.toString().trim() ??
        (isAdd ? '' : (approval?.requestedBy ?? ''));
    final addedBy = approval?.metadata['addedByName']?.toString().trim() ??
        _str(request, 'addedByName');

    return Scaffold(
      appBar: CfChromeAppBar(
        title: Text(isAdd ? 'Add player request' : 'Join request'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null && _payload == null
          ? SeriesEmptyState(
              icon: Icons.error_outline,
              title: 'Could not load this request',
              message: friendlyError(_loadError),
              action: FilledButton(
                onPressed: _load,
                child: const Text('Retry'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(AppDimens.spaceLg),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundImage: photoUrl.isEmpty
                          ? null
                          : NetworkImage(photoUrl),
                      child: photoUrl.isEmpty
                          ? Text(
                              displayName.isEmpty
                                  ? '?'
                                  : displayName[0].toUpperCase(),
                              style: const TextStyle(fontSize: 24),
                            )
                          : null,
                    ),
                    const SizedBox(width: AppDimens.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (displayName.isNotEmpty)
                            Text(
                              displayName,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            )
                          else if (playerUserId.isNotEmpty)
                            SeriesUserName(
                              playerUserId,
                              fallback: 'Player',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            )
                          else
                            const Text('Player'),
                          if (crickFlowId.isNotEmpty)
                            Text('CrickFlow ID: $crickFlowId'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.spaceLg),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text(status.label)),
                    if (clubReview.isNotEmpty)
                      Chip(label: Text(seriesClubReviewLabel(clubReview))),
                  ],
                ),
                if (teamName.isNotEmpty) _line(context, 'Team', teamName),
                if (orgName.isNotEmpty) _line(context, 'Organization', orgName),
                if (addedBy.isNotEmpty) _line(context, 'Added by', addedBy),
                if (submitted != null)
                  _line(context, 'Submitted', _formatSubmitted(submitted)),
                if (nationalId.isNotEmpty)
                  _line(context, 'National ID', nationalId),
                if (passport.isNotEmpty) _line(context, 'Passport', passport),
                if (phone.isNotEmpty) _line(context, 'Phone', phone),
                if (address.isNotEmpty) _line(context, 'Address', address),
                if (dob.isNotEmpty)
                  _line(context, 'Date of birth', dob.split('T').first),
                for (final e in custom.entries)
                  if ((e.value?.toString().trim() ?? '').isNotEmpty)
                    _line(
                      context,
                      seriesIdentityFieldLabel(e.key),
                      e.value.toString().trim(),
                    ),
                if (reason.isNotEmpty && !pending)
                  _line(context, 'Decision reason', reason),
                const SizedBox(height: AppDimens.spaceLg),
                SeriesDocumentImage(
                  url: _str(media, 'nationalIdDocUrl'),
                  label: 'National ID document',
                ),
                const SizedBox(height: AppDimens.spaceMd),
                SeriesDocumentImage(
                  url: _str(media, 'passportDocUrl'),
                  label: 'Passport document',
                ),
                const SizedBox(height: AppDimens.spaceXl),
                if (canAct) ...[
                  if (_acting)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: LinearProgressIndicator(),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _acting
                              ? null
                              : () => _review(
                                  approve: false,
                                  clubScope: clubScope,
                                ),
                          child: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: AppDimens.spaceSm),
                      Expanded(
                        child: FilledButton(
                          onPressed: _acting
                              ? null
                              : () => _review(
                                  approve: true,
                                  clubScope: clubScope,
                                ),
                          child: const Text('Approve'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }

  Widget _line(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: AppDimens.spaceSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }

  String _formatSubmitted(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}
