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

class CommunityTournamentCard extends ConsumerWidget {
  const CommunityTournamentCard({
    super.key,
    required this.snapshot,
    this.onShare,
    this.fallbackOrganizerUserId = '',
    this.fallbackOrganizerPlayerId,
    this.fallbackOrganizerPhotoUrl,
  });

  final CommunityTournamentSnapshot snapshot;
  final VoidCallback? onShare;

  /// Post author uid when snapshot predates [organizerUserId].
  final String fallbackOrganizerUserId;
  final String? fallbackOrganizerPlayerId;
  final String? fallbackOrganizerPhotoUrl;

  String get _organizerUserId =>
      snapshot.organizerUserId.isNotEmpty
          ? snapshot.organizerUserId
          : fallbackOrganizerUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final theme = Theme.of(context);
    final thumb = snapshot.thumbnailUrl;
    final showContact = _hasContact(snapshot, _organizerUserId);
    final isDm =
        snapshot.contactVisibility == CommunityContactVisibility.crickflowDm;

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
          AspectRatio(
            aspectRatio: snapshot.thumbnailAspect.displayRatio,
            child: thumb != null && thumb.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: thumb,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => ColoredBox(color: cf.card),
                    errorWidget: (_, _, _) => _thumbFallback(cf),
                  )
                : _thumbFallback(cf),
          ),
          Padding(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  snapshot.name.isNotEmpty ? snapshot.name : 'Tournament',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (snapshot.organizer.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Organizer · ${snapshot.organizer}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cf.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: AppDimens.spaceSm),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (snapshot.locationLabel.isNotEmpty)
                      _chip(
                        cf,
                        Icons.location_on_outlined,
                        snapshot.locationLabel,
                      ),
                    if (snapshot.startDate != null)
                      _chip(
                        cf,
                        Icons.event_outlined,
                        _dateRange(snapshot.startDate, snapshot.endDate),
                      ),
                    if (snapshot.entryFee != null &&
                        snapshot.entryFee!.isNotEmpty)
                      _chip(cf, Icons.payments_outlined, snapshot.entryFee!),
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
                    if (snapshot.teamCount != null)
                      _chip(
                        cf,
                        Icons.groups_outlined,
                        '${snapshot.teamCount} teams',
                      ),
                    if (snapshot.registrationStatus.isNotEmpty)
                      _chip(
                        cf,
                        Icons.how_to_reg_outlined,
                        snapshot.registrationStatus,
                      ),
                  ],
                ),
                if (showContact && !isDm) ...[
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
                        child: const Text('Join'),
                      ),
                    ),
                    if (isDm && _organizerUserId.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Message organizer',
                        child: OutlinedButton(
                          onPressed: () => _openOrganizerChat(context, ref),
                          child:
                              const Icon(Icons.chat_bubble_outline, size: 18),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: onShare,
                      child: const Icon(Icons.share_outlined, size: 18),
                    ),
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

  bool _hasContact(CommunityTournamentSnapshot s, String organizerUserId) {
    return switch (s.contactVisibility) {
      CommunityContactVisibility.hide => false,
      CommunityContactVisibility.phone => s.contactPhone.isNotEmpty,
      CommunityContactVisibility.whatsapp => s.contactWhatsApp.isNotEmpty,
      CommunityContactVisibility.email => s.contactEmail.isNotEmpty,
      CommunityContactVisibility.crickflowDm => organizerUserId.isNotEmpty,
    };
  }

  String _dateRange(DateTime? start, DateTime? end) {
    if (start == null) return '';
    final a = AppDateUtils.formatShort(start);
    if (end == null) return a;
    return '$a – ${AppDateUtils.formatShort(end)}';
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
