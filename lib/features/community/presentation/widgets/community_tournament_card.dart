import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/auth/auth_gate.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../data/models/community_post_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../shared/providers/chat_provider.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/providers/tournament_providers.dart';
import 'community_media_viewer.dart';
/// Tournament embed: name → organizer → thumbnail → details.
class CommunityTournamentCard extends ConsumerWidget {
  const CommunityTournamentCard({
    super.key,
    required this.snapshot,
    this.fallbackOrganizerUserId = '',
    this.fallbackOrganizerPlayerId,
    this.fallbackOrganizerPhotoUrl,
  });

  final CommunityTournamentSnapshot snapshot;
  final String fallbackOrganizerUserId;
  final String? fallbackOrganizerPlayerId;
  final String? fallbackOrganizerPhotoUrl;

  String get _organizerUserId => snapshot.organizerUserId.isNotEmpty
      ? snapshot.organizerUserId
      : fallbackOrganizerUserId;

  List<String> get _grounds {
    if (snapshot.grounds.isNotEmpty) {
      return snapshot.grounds
          .map((g) => g.trim())
          .where((g) => g.isNotEmpty)
          .toList();
    }
    final raw = snapshot.groundsLabel.trim();
    if (raw.isEmpty) return const [];
    if (raw.contains(' · ')) {
      return raw
          .split(' · ')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [raw];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final theme = Theme.of(context);
    final thumb = snapshot.thumbnailUrl;
    final isDm =
        snapshot.contactVisibility == CommunityContactVisibility.crickflowDm;
    final showExternalContact = _hasExternalContact(snapshot);
    var grounds = _grounds;
    if (grounds.isEmpty && snapshot.tournamentId.isNotEmpty) {
      final tournament =
          ref.watch(tournamentProvider(snapshot.tournamentId)).valueOrNull;
      grounds = [
        ...?tournament?.grounds
            .map((g) => g.trim())
            .where((g) => g.isNotEmpty),
      ];
      final primary = tournament?.setupMeta.primaryGround.trim() ?? '';
      if (primary.isNotEmpty &&
          !grounds.any((g) => g.toLowerCase() == primary.toLowerCase())) {
        grounds = [primary, ...grounds];
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: cf.sectionBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cf.border.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  snapshot.name.isNotEmpty ? snapshot.name : 'Tournament',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (snapshot.organizer.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Organizer: ${snapshot.organizer}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cf.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          AspectRatio(
            aspectRatio: snapshot.thumbnailAspect.displayRatio,
            child: thumb != null && thumb.isNotEmpty
                ? GestureDetector(
                    onTap: () => openCommunityMediaViewer(
                      context,
                      media: [
                        CommunityMediaItem(
                          url: thumb,
                          aspect: snapshot.thumbnailAspect,
                        ),
                      ],
                    ),
                    child: CachedNetworkImage(
                      imageUrl: thumb,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => ColoredBox(color: cf.card),
                      errorWidget: (_, _, _) => _thumbFallback(cf),
                    ),
                  )
                : _thumbFallback(cf),
          ),
          Padding(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (grounds.isNotEmpty) ...[
                  Text(
                    grounds.length == 1 ? 'Ground location' : 'Ground locations',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: cf.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...grounds.map(
                    (g) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: cf.accent,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              g,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimens.spaceSm),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (snapshot.startDate != null)
                      _chip(
                        cf,
                        Icons.event_outlined,
                        _dateRange(snapshot.startDate, snapshot.endDate),
                      ),
                    if (_dayCount(snapshot.startDate, snapshot.endDate)
                        case final days?)
                      _chip(
                        cf,
                        Icons.schedule_outlined,
                        days == 1 ? '1 day' : '$days days',
                      ),
                    if (snapshot.ballType.isNotEmpty)
                      _chip(
                        cf,
                        Icons.sports_baseball_outlined,
                        snapshot.ballType,
                      ),
                    if (snapshot.matchFormat.isNotEmpty)
                      _chip(
                        cf,
                        Icons.grid_view_outlined,
                        snapshot.matchFormat,
                      ),
                    if (snapshot.registrationStatus.isNotEmpty)
                      _chip(
                        cf,
                        Icons.how_to_reg_outlined,
                        snapshot.registrationStatus,
                      ),
                  ],
                ),
                if (showExternalContact) ...[
                  const SizedBox(height: AppDimens.spaceSm),
                  _ExternalContactRow(snapshot: snapshot),
                ],
                const SizedBox(height: AppDimens.spaceSm),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: snapshot.tournamentId.isEmpty
                            ? null
                            : () => context.push(
                                  '/tournaments/${snapshot.tournamentId}',
                                ),
                        child: const Text('View tournament'),
                      ),
                    ),
                    if (isDm && _organizerUserId.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => _openOrganizerChat(context, ref),
                        child: const Text('Chat'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openOrganizerChat(BuildContext context, WidgetRef ref) async {
    final organizerId = _organizerUserId;
    if (organizerId.isEmpty) return;

    requireAuthVoid(
      context: context,
      ref: ref,
      action: () async {
        final me = ref.read(currentUserProfileProvider).valueOrNull;
        if (me == null) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sign in to message')),
            );
          }
          return;
        }
        if (me.id == organizerId) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('This is your tournament')),
            );
          }
          return;
        }

        final other = UserModel(
          id: organizerId,
          email: '',
          name: snapshot.organizer,
          photoUrl: snapshot.organizerPhotoUrl ?? fallbackOrganizerPhotoUrl,
          playerId: snapshot.organizerPlayerId.isNotEmpty
              ? snapshot.organizerPlayerId
              : fallbackOrganizerPlayerId,
        );

        try {
          final chatId =
              await ref.read(chatRepositoryProvider).openOrCreateChat(
                    me: me,
                    other: other,
                  );
          if (context.mounted) {
            context.push('/community/chats/$chatId');
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$e')),
            );
          }
        }
      },
    );
  }

  Widget _thumbFallback(CfColors cf) {
    return ColoredBox(
      color: cf.card,
      child: Center(
        child: Icon(Icons.emoji_events_outlined, size: 40, color: cf.textMuted),
      ),
    );
  }

  Widget _chip(CfColors cf, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cf.card,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: cf.textMuted),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: cf.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  bool _hasExternalContact(CommunityTournamentSnapshot s) {
    return switch (s.contactVisibility) {
      CommunityContactVisibility.phone => s.contactPhone.isNotEmpty,
      CommunityContactVisibility.whatsapp => s.contactWhatsApp.isNotEmpty,
      CommunityContactVisibility.email => s.contactEmail.isNotEmpty,
      CommunityContactVisibility.hide ||
      CommunityContactVisibility.crickflowDm =>
        false,
    };
  }

  String _dateRange(DateTime? start, DateTime? end) {
    if (start == null) return '';
    final a = AppDateUtils.formatShort(start);
    if (end == null) return a;
    return '$a – ${AppDateUtils.formatShort(end)}';
  }

  /// Inclusive calendar-day span (same start/end → 1 day).
  int? _dayCount(DateTime? start, DateTime? end) {
    if (start == null) return null;
    final s = DateTime(start.year, start.month, start.day);
    final e = end == null
        ? s
        : DateTime(end.year, end.month, end.day);
    final days = e.difference(s).inDays + 1;
    return days < 1 ? 1 : days;
  }
}

class _ExternalContactRow extends StatelessWidget {
  const _ExternalContactRow({required this.snapshot});

  final CommunityTournamentSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final (icon, label, onTap) = switch (snapshot.contactVisibility) {
      CommunityContactVisibility.phone => (
          Icons.phone_outlined,
          snapshot.contactPhone,
          () => launchUrl(Uri(scheme: 'tel', path: snapshot.contactPhone)),
        ),
      CommunityContactVisibility.whatsapp => (
          Icons.chat_outlined,
          snapshot.contactWhatsApp,
          () {
            final phone =
                snapshot.contactWhatsApp.replaceAll(RegExp(r'\D'), '');
            launchUrl(
              Uri.parse('https://wa.me/$phone'),
              mode: LaunchMode.externalApplication,
            );
          },
        ),
      CommunityContactVisibility.email => (
          Icons.email_outlined,
          snapshot.contactEmail,
          () => launchUrl(
                Uri(
                  scheme: 'mailto',
                  path: snapshot.contactEmail,
                ),
              ),
        ),
      CommunityContactVisibility.hide ||
      CommunityContactVisibility.crickflowDm => (
          Icons.visibility_off_outlined,
          '',
          null,
        ),
    };

    if (label.isEmpty) return const SizedBox.shrink();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: cf.accent),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cf.accent,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
