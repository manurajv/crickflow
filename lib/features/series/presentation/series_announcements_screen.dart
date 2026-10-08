import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../data/models/series/series.dart';
import '../../../shared/providers/series_providers.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';
import 'widgets/series_ui.dart';
import 'widgets/series_user_name.dart';

/// Org announcements: everyone signed in can read; owner + admins can post.
class SeriesAnnouncementsScreen extends ConsumerWidget {
  const SeriesAnnouncementsScreen({super.key, required this.seriesId});
  final String seriesId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final role = ref.watch(mySeriesRoleProvider(seriesId));
    final series = ref.watch(seriesByIdProvider(seriesId)).valueOrNull;
    final canPost =
        role == SeriesRole.superAdmin || role == SeriesRole.seriesAdmin;
    final signedIn = FirebaseAuth.instance.currentUser != null;
    final active = series?.status == SeriesStatus.active;

    return Scaffold(
      backgroundColor: cf.background,
      appBar: const CfChromeAppBar(title: Text('Announcements')),
      floatingActionButton: canPost && active
          ? FloatingActionButton.extended(
              backgroundColor: cf.fabBackground,
              foregroundColor: cf.fabForeground,
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => _ComposeSheet(seriesId: seriesId),
              ),
              icon: const Icon(Icons.campaign_outlined),
              label: const Text('New announcement'),
            )
          : null,
      body: !signedIn
          ? const SeriesEmptyState(
              icon: Icons.lock_outline,
              title: 'Sign in to see announcements',
            )
          : ref.watch(seriesAnnouncementsProvider(seriesId)).when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (items) => items.isEmpty
                    ? SeriesEmptyState(
                        icon: Icons.campaign_outlined,
                        title: 'No announcements yet',
                        message: canPost
                            ? (active
                                ? 'Share fixtures, deadlines and news with your clubs and players.'
                                : 'Announcements are paused while the organization is not active.')
                            : 'News from the organizers will show up here.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppDimens.spaceMd,
                          AppDimens.spaceMd,
                          AppDimens.spaceMd,
                          96,
                        ),
                        itemCount: items.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppDimens.spaceSm),
                        itemBuilder: (_, i) => SeriesAnnouncementCard(
                          announcement: items[i],
                          showAudience: canPost,
                        ),
                      ),
              ),
    );
  }
}

class SeriesAnnouncementCard extends StatelessWidget {
  const SeriesAnnouncementCard({
    super.key,
    required this.announcement,
    this.showAudience = false,
  });

  final SeriesAnnouncementModel announcement;
  final bool showAudience;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final a = announcement;
    final meta = TextStyle(color: cf.textSecondary, fontSize: 12);
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: cf.surface,
        border: Border.all(color: cf.border),
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.campaign_outlined, color: cf.accent, size: 20),
              const SizedBox(width: AppDimens.spaceSm),
              Expanded(
                child: Text(
                  a.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(a.body),
          const SizedBox(height: AppDimens.spaceSm),
          Row(
            children: [
              Flexible(
                child: a.createdByName.isNotEmpty
                    ? Text(a.createdByName, style: meta)
                    : SeriesUserName(a.createdBy, fallback: 'Organizer', style: meta),
              ),
              Text(' · ${seriesShortDate(a.createdAt)}', style: meta),
              if (showAudience)
                Text(
                  ' · ${a.audience.label} (${a.recipientCount})',
                  style: meta,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ComposeSheet extends ConsumerStatefulWidget {
  const _ComposeSheet({required this.seriesId});
  final String seriesId;

  @override
  ConsumerState<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends ConsumerState<_ComposeSheet> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  SeriesAnnouncementAudience _audience = SeriesAnnouncementAudience.all;
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.length < 3 || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a title (3+ characters) and a message')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      final result =
          await ref.read(seriesFunctionsServiceProvider).sendSeriesAnnouncement(
                seriesId: widget.seriesId,
                title: title,
                body: body,
                audience: _audience.name,
              );
      if (!mounted) return;
      final count = (result['recipientCount'] as num?)?.toInt() ?? 0;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Announcement sent to $count ${count == 1 ? 'person' : 'people'}',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not send: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimens.spaceLg,
        0,
        AppDimens.spaceLg,
        MediaQuery.viewInsetsOf(context).bottom + AppDimens.spaceLg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'New announcement',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppDimens.spaceMd),
          TextField(
            controller: _title,
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          TextField(
            controller: _body,
            minLines: 3,
            maxLines: 6,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Message',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text('Send to', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppDimens.spaceXs),
          Wrap(
            spacing: AppDimens.spaceSm,
            children: [
              for (final a in SeriesAnnouncementAudience.values)
                ChoiceChip(
                  label: Text(a.label),
                  selected: _audience == a,
                  onSelected: _sending
                      ? null
                      : (_) => setState(() => _audience = a),
                ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceLg),
          FilledButton.icon(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(_sending ? 'Sending…' : 'Send'),
          ),
        ],
      ),
    );
  }
}
