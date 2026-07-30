import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../models/managed_notification.dart';
import '../../models/notification_enums.dart';
import '../../providers/notifications_providers.dart';

class NotificationComposerPanel extends ConsumerStatefulWidget {
  const NotificationComposerPanel({
    super.key,
    required this.onClose,
    this.initial,
  });

  final VoidCallback onClose;
  final ManagedNotificationCampaign? initial;

  @override
  ConsumerState<NotificationComposerPanel> createState() =>
      _NotificationComposerPanelState();
}

class _NotificationComposerPanelState
    extends ConsumerState<NotificationComposerPanel> {
  late final TextEditingController _title;
  late final TextEditingController _subtitle;
  late final TextEditingController _body;
  late final TextEditingController _imageUrl;
  late final TextEditingController _bannerUrl;
  late final TextEditingController _actionButton;
  late final TextEditingController _deepLink;
  late final TextEditingController _timezone;
  late final TextEditingController _campaignName;
  late final TextEditingController _specificUserIds;

  late ManagedNotificationType _type;
  late ManagedNotificationPriority _priority;
  late ManagedNotificationSound _sound;
  late ManagedNotificationAudience _audience;
  late ManagedScheduleMode _scheduleMode;
  late ManagedRecurrence _recurrence;
  late DateTime? _scheduledAt;
  late bool _isCampaign;
  bool _busy = false;

  NotificationsHubController get _controller =>
      ref.read(notificationsHubControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    final i = widget.initial ??
        const ManagedNotificationCampaign(id: '', title: '');
    _title = TextEditingController(text: i.title);
    _subtitle = TextEditingController(text: i.subtitle);
    _body = TextEditingController(text: i.body);
    _imageUrl = TextEditingController(text: i.imageUrl);
    _bannerUrl = TextEditingController(text: i.bannerUrl);
    _actionButton = TextEditingController(text: i.actionButtonText);
    _deepLink = TextEditingController(text: i.deepLink);
    _timezone = TextEditingController(text: i.timezone);
    _campaignName = TextEditingController(text: i.campaignName);
    _specificUserIds = TextEditingController(
      text: i.audienceIds.join(', '),
    );
    _type = i.type;
    _priority = i.priority;
    _sound = i.sound;
    _audience = i.audience;
    _scheduleMode = i.scheduleMode;
    _recurrence = i.recurrence;
    _scheduledAt = i.scheduledAt;
    _isCampaign = i.isCampaign;
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _body.dispose();
    _imageUrl.dispose();
    _bannerUrl.dispose();
    _actionButton.dispose();
    _deepLink.dispose();
    _timezone.dispose();
    _campaignName.dispose();
    _specificUserIds.dispose();
    super.dispose();
  }

  ManagedNotificationCampaign _buildCampaign() {
    final initial = widget.initial;
    final audienceIds = _audience == ManagedNotificationAudience.specificUsers
        ? _specificUserIds.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList()
        : <String>[];

    return ManagedNotificationCampaign(
      id: initial?.id ?? '',
      title: _title.text.trim().isEmpty ? 'Untitled' : _title.text.trim(),
      subtitle: _subtitle.text.trim(),
      body: _body.text.trim(),
      imageUrl: _imageUrl.text.trim(),
      bannerUrl: _bannerUrl.text.trim(),
      actionButtonText: _actionButton.text.trim(),
      deepLink: _deepLink.text.trim(),
      type: _type,
      priority: _priority,
      sound: _sound,
      audience: _audience,
      audienceIds: audienceIds,
      scheduleMode: _scheduleMode,
      scheduledAt: _scheduledAt,
      recurrence: _recurrence,
      timezone: _timezone.text.trim().isEmpty ? 'UTC' : _timezone.text.trim(),
      campaignName: _campaignName.text.trim(),
      isCampaign: _isCampaign,
      status: initial?.status ?? ManagedNotificationStatus.draft,
      createdByUid: initial?.createdByUid ?? '',
      createdByEmail: initial?.createdByEmail ?? '',
    );
  }

  Future<void> _saveDraft() async {
    setState(() => _busy = true);
    try {
      final c = _buildCampaign();
      if (c.id.isEmpty) {
        await _controller.saveDraft(c);
      } else {
        await _controller.updateDraft(c);
      }
      if (mounted) {
        widget.onClose();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Draft saved')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendNow() async {
    setState(() => _busy = true);
    try {
      await _controller.sendNow(_buildCampaign());
      if (mounted) {
        widget.onClose();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification queued for delivery')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _schedule() async {
    final at = _scheduledAt ?? DateTime.now().add(const Duration(hours: 1));
    setState(() => _busy = true);
    try {
      await _controller.schedule(
        _buildCampaign(),
        at: at,
        recurrence: _recurrence,
        timezone: _timezone.text.trim().isEmpty ? 'UTC' : _timezone.text.trim(),
      );
      if (mounted) {
        widget.onClose();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification scheduled')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickScheduleDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt ?? DateTime.now()),
    );
    if (time == null || !mounted) return;
    setState(() {
      _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;

    return Material(
      color: colors.surface,
      elevation: 8,
      child: SizedBox(
        width: 460,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.initial?.id.isEmpty ?? true
                          ? 'Create notification'
                          : 'Edit notification',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colors.info.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.info.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: colors.info),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mass audiences are queued for a delivery worker. '
                      'Specific users (≤50) write in-app inbox docs. '
                      'FCM tokens are never accessed.',
                      style: TextStyle(
                        color: colors.info,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  TextField(
                    controller: _title,
                    decoration: const InputDecoration(labelText: 'Title *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _subtitle,
                    decoration: const InputDecoration(labelText: 'Subtitle'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _body,
                    decoration: const InputDecoration(labelText: 'Body *'),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _imageUrl,
                    decoration: const InputDecoration(labelText: 'Image URL'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bannerUrl,
                    decoration: const InputDecoration(labelText: 'Banner URL'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _actionButton,
                    decoration:
                        const InputDecoration(labelText: 'Action button text'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _deepLink,
                    decoration: const InputDecoration(labelText: 'Deep link'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<ManagedNotificationType>(
                    value: _type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: [
                      for (final t in ManagedNotificationType.values)
                        DropdownMenuItem(value: t, child: Text(t.label)),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _type = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ManagedNotificationPriority>(
                    value: _priority,
                    decoration: const InputDecoration(labelText: 'Priority'),
                    items: [
                      for (final p in ManagedNotificationPriority.values)
                        DropdownMenuItem(value: p, child: Text(p.label)),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _priority = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ManagedNotificationSound>(
                    value: _sound,
                    decoration: const InputDecoration(labelText: 'Sound'),
                    items: [
                      for (final s in ManagedNotificationSound.values)
                        DropdownMenuItem(value: s, child: Text(s.label)),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _sound = v);
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<ManagedNotificationAudience>(
                    value: _audience,
                    decoration: const InputDecoration(labelText: 'Audience'),
                    items: [
                      for (final a in ManagedNotificationAudience.values)
                        DropdownMenuItem(value: a, child: Text(a.label)),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _audience = v);
                    },
                  ),
                  if (_audience == ManagedNotificationAudience.specificUsers) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _specificUserIds,
                      decoration: const InputDecoration(
                        labelText: 'User IDs (comma-separated, max 50)',
                        helperText: 'Writes in-app inbox docs — no push tokens',
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text('Schedule mode',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  SegmentedButton<ManagedScheduleMode>(
                    segments: [
                      for (final m in ManagedScheduleMode.values)
                        ButtonSegment(value: m, label: Text(m.label)),
                    ],
                    selected: {_scheduleMode},
                    onSelectionChanged: (s) =>
                        setState(() => _scheduleMode = s.first),
                  ),
                  if (_scheduleMode != ManagedScheduleMode.immediate) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _pickScheduleDateTime,
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(
                        _scheduledAt == null
                            ? 'Pick date & time'
                            : _scheduledAt!.toLocal().toString().substring(0, 16),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ManagedRecurrence>(
                      value: _recurrence,
                      decoration:
                          const InputDecoration(labelText: 'Recurrence'),
                      items: [
                        for (final r in ManagedRecurrence.values)
                          DropdownMenuItem(value: r, child: Text(r.label)),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _recurrence = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _timezone,
                      decoration: const InputDecoration(
                        labelText: 'Timezone',
                        hintText: 'UTC',
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Part of campaign'),
                    value: _isCampaign,
                    onChanged: (v) => setState(() => _isCampaign = v),
                  ),
                  if (_isCampaign) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _campaignName,
                      decoration:
                          const InputDecoration(labelText: 'Campaign name'),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CfButton(
                    label: 'Save Draft',
                    variant: CfButtonVariant.secondary,
                    isLoading: _busy,
                    onPressed: _busy ? null : _saveDraft,
                    expanded: true,
                  ),
                  const SizedBox(height: 8),
                  if (_scheduleMode == ManagedScheduleMode.immediate)
                    CfButton(
                      label: 'Send Now / Queue',
                      isLoading: _busy,
                      onPressed: _busy ? null : _sendNow,
                      expanded: true,
                    )
                  else
                    CfButton(
                      label: 'Schedule',
                      isLoading: _busy,
                      onPressed: _busy ? null : _schedule,
                      expanded: true,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
