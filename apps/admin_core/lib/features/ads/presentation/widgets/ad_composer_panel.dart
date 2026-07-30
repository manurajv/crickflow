import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../models/ads_enums.dart';
import '../../models/managed_ads.dart';
import '../../providers/ads_providers.dart';

class AdComposerPanel extends ConsumerStatefulWidget {
  const AdComposerPanel({
    super.key,
    required this.onClose,
    this.initial,
  });

  final VoidCallback onClose;
  final ManagedAdCampaign? initial;

  @override
  ConsumerState<AdComposerPanel> createState() => _AdComposerPanelState();
}

class _AdComposerPanelState extends ConsumerState<AdComposerPanel> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _campaignName;
  late final TextEditingController _thumbnailUrl;
  late final TextEditingController _bannerUrl;
  late final TextEditingController _videoUrl;
  late final TextEditingController _destinationUrl;
  late final TextEditingController _buttonText;
  late final TextEditingController _advertiserName;
  late final TextEditingController _country;
  late final TextEditingController _stateProvince;
  late final TextEditingController _city;
  late final TextEditingController _language;
  late final TextEditingController _matchType;
  late final TextEditingController _ballType;
  late final TextEditingController _tournamentId;
  late final TextEditingController _priority;
  late final TextEditingController _weight;

  late ManagedAdMediaType _mediaType;
  late ManagedAdCampaignType _campaignType;
  late ManagedAdStatus _status;
  late Set<ManagedAdPlacement> _placements;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _busy = false;

  AdsHubController get _controller =>
      ref.read(adsHubControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    final i = widget.initial ?? const ManagedAdCampaign(id: '', title: '');
    _title = TextEditingController(text: i.title);
    _description = TextEditingController(text: i.description);
    _campaignName = TextEditingController(text: i.campaignName);
    _thumbnailUrl = TextEditingController(text: i.thumbnailUrl);
    _bannerUrl = TextEditingController(text: i.bannerUrl);
    _videoUrl = TextEditingController(text: i.videoUrl);
    _destinationUrl = TextEditingController(text: i.destinationUrl);
    _buttonText = TextEditingController(text: i.buttonText);
    _advertiserName = TextEditingController(text: i.advertiserName);
    _country = TextEditingController(text: i.country);
    _stateProvince = TextEditingController(text: i.stateProvince);
    _city = TextEditingController(text: i.city);
    _language = TextEditingController(text: i.language);
    _matchType = TextEditingController(text: i.matchType);
    _ballType = TextEditingController(text: i.ballType);
    _tournamentId = TextEditingController(text: i.tournamentId ?? '');
    _priority = TextEditingController(text: '${i.priority}');
    _weight = TextEditingController(text: '${i.weight}');
    _mediaType = i.mediaType;
    _campaignType = i.campaignType;
    _status = i.status == ManagedAdStatus.draft ||
            i.status == ManagedAdStatus.pendingApproval
        ? i.status
        : ManagedAdStatus.draft;
    _placements = {...i.placements};
    _startDate = i.startDate;
    _endDate = i.endDate;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _campaignName.dispose();
    _thumbnailUrl.dispose();
    _bannerUrl.dispose();
    _videoUrl.dispose();
    _destinationUrl.dispose();
    _buttonText.dispose();
    _advertiserName.dispose();
    _country.dispose();
    _stateProvince.dispose();
    _city.dispose();
    _language.dispose();
    _matchType.dispose();
    _ballType.dispose();
    _tournamentId.dispose();
    _priority.dispose();
    _weight.dispose();
    super.dispose();
  }

  ManagedAdCampaign _buildCampaign() {
    final initial = widget.initial;
    final actor = ref.read(adminSessionProvider).adminUser;
    return ManagedAdCampaign(
      id: initial?.id ?? '',
      title: _title.text.trim().isEmpty ? 'Untitled' : _title.text.trim(),
      description: _description.text.trim(),
      campaignName: _campaignName.text.trim(),
      mediaType: _mediaType,
      thumbnailUrl: _thumbnailUrl.text.trim(),
      bannerUrl: _bannerUrl.text.trim(),
      videoUrl: _videoUrl.text.trim(),
      destinationUrl: _destinationUrl.text.trim(),
      buttonText: _buttonText.text.trim().isEmpty
          ? 'Learn more'
          : _buttonText.text.trim(),
      status: _status,
      campaignType: _campaignType,
      placements: _placements.isEmpty ? {ManagedAdPlacement.home} : _placements,
      priority: int.tryParse(_priority.text.trim()) ?? 0,
      weight: int.tryParse(_weight.text.trim()) ?? 1,
      startDate: _startDate,
      endDate: _endDate,
      advertiserName: _advertiserName.text.trim(),
      country: _country.text.trim(),
      stateProvince: _stateProvince.text.trim(),
      city: _city.text.trim(),
      language: _language.text.trim(),
      matchType: _matchType.text.trim(),
      ballType: _ballType.text.trim(),
      tournamentId: _tournamentId.text.trim().isEmpty
          ? null
          : _tournamentId.text.trim(),
      createdByUid: initial?.createdByUid ?? actor?.uid ?? '',
      createdByEmail: initial?.createdByEmail ?? actor?.email ?? '',
    );
  }

  Future<void> _saveDraft() async {
    setState(() => _busy = true);
    try {
      final c = _buildCampaign().copyWith(status: ManagedAdStatus.draft);
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

  Future<void> _submitForApproval() async {
    setState(() => _busy = true);
    try {
      await _controller.submitForApproval(_buildCampaign());
      if (mounted) {
        widget.onClose();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Submitted for approval')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDate({required bool start}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (start ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) {
      setState(() {
        if (start) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final dateFmt = MaterialLocalizations.of(context);

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
                          ? 'Create advertisement'
                          : 'Edit advertisement',
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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  TextField(
                    controller: _title,
                    decoration: const InputDecoration(labelText: 'Title *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _description,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _campaignName,
                    decoration: const InputDecoration(labelText: 'Campaign name'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ManagedAdMediaType>(
                    value: _mediaType,
                    decoration: const InputDecoration(labelText: 'Media type'),
                    items: [
                      for (final m in ManagedAdMediaType.values)
                        DropdownMenuItem(value: m, child: Text(m.label)),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _mediaType = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _thumbnailUrl,
                    decoration: const InputDecoration(labelText: 'Thumbnail URL'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bannerUrl,
                    decoration: const InputDecoration(labelText: 'Banner / image URL'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _videoUrl,
                    decoration: const InputDecoration(labelText: 'Video URL'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _destinationUrl,
                    decoration: const InputDecoration(labelText: 'Destination URL'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _buttonText,
                    decoration: const InputDecoration(labelText: 'Button text'),
                  ),
                  const SizedBox(height: 16),
                  Text('Placements',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in ManagedAdPlacement.values)
                        FilterChip(
                          label: Text(p.label),
                          selected: _placements.contains(p),
                          onSelected: (v) => setState(() {
                            if (v) {
                              _placements.add(p);
                            } else {
                              _placements.remove(p);
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Targeting',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _country,
                    decoration: const InputDecoration(labelText: 'Country'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _stateProvince,
                    decoration: const InputDecoration(labelText: 'State / Province'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _city,
                    decoration: const InputDecoration(labelText: 'City'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _language,
                    decoration: const InputDecoration(labelText: 'Language'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _matchType,
                    decoration: const InputDecoration(labelText: 'Match type'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _ballType,
                    decoration: const InputDecoration(labelText: 'Ball type'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _tournamentId,
                    decoration: const InputDecoration(labelText: 'Tournament ID'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickDate(start: true),
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(
                            _startDate == null
                                ? 'Start date'
                                : dateFmt.formatShortDate(_startDate!),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickDate(start: false),
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(
                            _endDate == null
                                ? 'End date'
                                : dateFmt.formatShortDate(_endDate!),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _priority,
                          decoration: const InputDecoration(labelText: 'Priority'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _weight,
                          decoration: const InputDecoration(labelText: 'Weight'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _advertiserName,
                    decoration: const InputDecoration(labelText: 'Advertiser name'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ManagedAdCampaignType>(
                    value: _campaignType,
                    decoration: const InputDecoration(labelText: 'Campaign type'),
                    items: [
                      for (final t in ManagedAdCampaignType.values)
                        DropdownMenuItem(value: t, child: Text(t.label)),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _campaignType = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ManagedAdStatus>(
                    value: _status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(
                        value: ManagedAdStatus.draft,
                        child: Text('Draft'),
                      ),
                      DropdownMenuItem(
                        value: ManagedAdStatus.pendingApproval,
                        child: Text('Pending Approval'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _status = v);
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: CfButton(
                      label: 'Save Draft',
                      variant: CfButtonVariant.secondary,
                      onPressed: _busy ? null : _saveDraft,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CfButton(
                      label: 'Submit for Approval',
                      onPressed: _busy ? null : _submitForApproval,
                    ),
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
